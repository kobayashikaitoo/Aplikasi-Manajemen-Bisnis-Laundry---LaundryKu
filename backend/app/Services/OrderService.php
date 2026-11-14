<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Customer;
use App\Models\LoyaltyTransaction;
use App\Models\Notification;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusLog;
use App\Models\Service;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OrderService
{
    /**
     * Generate sequential gapless order number inside transaction with row locking.
     * Format: LDRY-YYYYMMDD-NNNN
     */
    public function generateOrderNo(int $branchId): string
    {
        $dateStr = Carbon::now('UTC')->format('Ymd');
        $prefix = "LDRY-{$dateStr}-";

        // Lock existing orders for today to avoid race condition gaps
        $lastOrder = Order::where('order_no', 'like', "{$prefix}%")
            ->orderBy('order_no', 'desc')
            ->lockForUpdate()
            ->first();

        if ($lastOrder) {
            $lastNum = (int) substr($lastOrder->order_no, -4);
            $nextNum = $lastNum + 1;
        } else {
            $nextNum = 1;
        }

        return $prefix . str_pad((string) $nextNum, 4, '0', STR_PAD_LEFT);
    }

    /**
     * Create order with snapshot pricing, gapless order_no, and discount validation.
     */
    public function createOrder(array $data, User $creator, ?string $idempotencyKey = null): Order
    {
        return DB::transaction(function () use ($data, $creator, $idempotencyKey) {
            $branchId = $data['branch_id'] ?? $creator->branch_id ?? 1;
            $customer = Customer::findOrFail($data['customer_id']);

            // 1. Calculate items with price snapshot
            $itemsData = [];
            $subtotal = 0;

            foreach ($data['items'] as $itemInput) {
                $service = Service::where('id', $itemInput['service_id'])
                    ->where('is_active', true)
                    ->firstOrFail();

                $rawQty = (float) $itemInput['quantity'];
                // BR-03: Kiloan min 1 kg, rounding 0.1 kg
                if (strtolower($service->unit) === 'kg') {
                    $rawQty = round($rawQty, 1);
                    if ($rawQty < (float) $service->min_order) {
                        $rawQty = (float) $service->min_order;
                    }
                } else {
                    if ($rawQty < 1.0) {
                        $rawQty = 1.0;
                    }
                }

                $unitPrice = (int) $service->price; // Snapshot harga BR-01
                $itemSubtotal = (int) round($unitPrice * $rawQty);

                $subtotal += $itemSubtotal;

                $itemsData[] = [
                    'service_id' => $service->id,
                    'service_name_snap' => $service->name,
                    'unit_snap' => $service->unit,
                    'unit_price' => $unitPrice,
                    'quantity' => $rawQty,
                    'subtotal' => $itemSubtotal,
                ];
            }

            // 2. Validate Discount (BR-11) & Point Redemption (FR-PNT-02)
            $manualDiscount = (int) ($data['discount_amount'] ?? 0);
            $pointsRedeemed = (int) ($data['points_redeemed'] ?? 0);
            $pointDiscount = 0;

            if ($pointsRedeemed > 0) {
                if ($customer->point_balance < $pointsRedeemed) {
                    throw ValidationException::withMessages([
                        'points_redeemed' => "Saldo poin tidak mencukupi. Saldo tersedia: {$customer->point_balance} poin.",
                    ]);
                }
                // 1 Poin = Rp1.000 potongan harga langsung
                $pointDiscount = $pointsRedeemed * 1000;
            }

            if ($manualDiscount > 0) {
                $maxAllowedDiscountWithoutOwner = (int) floor($subtotal * 0.10);
                if ($manualDiscount > $maxAllowedDiscountWithoutOwner && !$creator->isOwner()) {
                    throw ValidationException::withMessages([
                        'discount_amount' => 'Diskon manual di atas 10% subtotal harus disetujui atau dibuat oleh pemilik cabang.',
                    ]);
                }
            }

            $discountAmount = min($subtotal, $manualDiscount + $pointDiscount);
            $totalAmount = max(0, $subtotal - $discountAmount);

            // 3. Generate Order No (FR-AUD-05)
            $orderNo = $this->generateOrderNo($branchId);

            // Branch holding period setting
            $holdingPeriodDays = $customer->branch?->settings?->holding_period_days ?? 7;

            // 4. Create Order
            $order = Order::create([
                'branch_id' => $branchId,
                'customer_id' => $customer->id,
                'created_by_user_id' => $creator->id,
                'order_no' => $orderNo,
                'barcode' => $orderNo,
                'status' => OrderStatus::Diterima->value,
                'subtotal' => $subtotal,
                'discount_amount' => $discountAmount,
                'total_amount' => $totalAmount,
                'holding_period_days' => $holdingPeriodDays,
                'due_at' => null,
                'completed_at' => null,
                'pickup_at' => null,
                'notes' => $data['notes'] ?? null,
            ]);

            // Save items
            foreach ($itemsData as $item) {
                $order->items()->create($item);
            }

            // Deduct customer points if redeemed
            if ($pointsRedeemed > 0) {
                $newBalance = max(0, $customer->point_balance - $pointsRedeemed);
                $customer->point_balance = $newBalance;
                $customer->save();

                LoyaltyTransaction::create([
                    'customer_id' => $customer->id,
                    'order_id' => $order->id,
                    'type' => 'redeem',
                    'points' => $pointsRedeemed,
                    'balance_after' => $newBalance,
                    'description' => "Tukar {$pointsRedeemed} poin untuk potongan pesanan #{$orderNo}",
                ]);
            }

            // 5. Initial status log
            OrderStatusLog::create([
                'order_id' => $order->id,
                'from_status' => null,
                'to_status' => OrderStatus::Diterima->value,
                'changed_by_user_id' => $creator->id,
                'reason' => 'Order baru dibuat',
            ]);

            // 6. Audit log for discount if applied
            if ($discountAmount > 0) {
                AuditService::log(
                    action: 'apply_discount',
                    entityType: 'Order',
                    entityId: (string) $order->id,
                    oldValues: ['discount_amount' => 0],
                    newValues: [
                        'discount_amount' => $discountAmount,
                        'subtotal' => $subtotal,
                        'total_amount' => $totalAmount,
                    ],
                    userId: $creator->id
                );
            }

            return $order->load(['items', 'customer', 'branch', 'createdBy']);
        });
    }

    /**
     * State machine transition (FR-STA-01, BR-13).
     */
    public function transition(Order $order, OrderStatus $target, User $actor, ?string $reason = null): Order
    {
        return DB::transaction(function () use ($order, $target, $actor, $reason) {
            // Lock order for update
            $order = Order::where('id', $order->id)->lockForUpdate()->firstOrFail();

            $currentStatus = OrderStatus::from($order->status);

            if ($currentStatus === $target) {
                return $order;
            }

            // Check if backward transition
            $isBackward = !$currentStatus->canTransitionTo($target);

            if ($isBackward) {
                // BR-13: Transisi mundur hanya oleh pemilik dengan alasan tertulis
                if (!$actor->isOwner()) {
                    throw ValidationException::withMessages([
                        'status' => "Transisi status dari '{$currentStatus->value}' ke '{$target->value}' tidak diizinkan.",
                    ]);
                }

                if (empty(trim($reason ?? ''))) {
                    throw ValidationException::withMessages([
                        'reason' => "Alasan tertulis wajib diisi untuk transisi status mundur oleh pemilik.",
                    ]);
                }
            } else {
                // Forward transition rules
                // FR-KLM-01: Diterima -> Ditimbang wajib ada foto kondisi awal (photo_type == 'initial')
                if ($currentStatus === OrderStatus::Diterima && $target === OrderStatus::Ditimbang) {
                    $hasInitialPhoto = $order->photos()->where('photo_type', 'initial')->exists();
                    if (!$hasInitialPhoto) {
                        throw ValidationException::withMessages([
                            'photos' => 'Foto kondisi awal wajib diunggah sebelum status Ditimbang.',
                        ]);
                    }
                }

                // Cancellation check: Dibatalkan only from Diterima or Ditimbang with owner approval and reason
                if ($target === OrderStatus::Dibatalkan) {
                    if (!$actor->isOwner() && !$actor->isStaff()) {
                        throw ValidationException::withMessages([
                            'status' => 'Pembatalan order hanya dapat dilakukan oleh pegawai atau pemilik.',
                        ]);
                    }
                    if (empty(trim($reason ?? ''))) {
                        throw ValidationException::withMessages([
                            'reason' => 'Alasan pembatalan order wajib diisi.',
                        ]);
                    }
                }
            }

            // Execute transition effects
            $order->status = $target->value;

            if ($target === OrderStatus::Siap) {
                // Completed effects (BR-06, FR-STA-04): completed_at, due_at, notification
                $order->completed_at = Carbon::now('UTC');
                $order->due_at = Carbon::now('UTC')->addDays($order->holding_period_days);

                // Notify customer if customer has user account
                $customerUser = $order->customer?->user;
                if ($customerUser) {
                    Notification::create([
                        'user_id' => $customerUser->id,
                        'order_id' => $order->id,
                        'type' => 'ready',
                        'title' => 'Cucian Selesai!',
                        'message' => "Order #{$order->order_no} telah selesai diproses dan siap diambil. Batas pengambilan: " . $order->due_at->format('d M Y H:i') . " WITA.",
                    ]);
                }
            }

            if ($target === OrderStatus::Diambil) {
                $order->pickup_at = Carbon::now('UTC');
            }

            $order->save();

            // Record status log in same transaction
            OrderStatusLog::create([
                'order_id' => $order->id,
                'from_status' => $currentStatus->value,
                'to_status' => $target->value,
                'changed_by_user_id' => $actor->id,
                'reason' => $reason,
            ]);

            // Audit log if backward or canceled
            if ($isBackward || $target === OrderStatus::Dibatalkan) {
                AuditService::log(
                    action: $isBackward ? 'rollback_status' : 'cancel_order',
                    entityType: 'Order',
                    entityId: (string) $order->id,
                    oldValues: ['status' => $currentStatus->value],
                    newValues: ['status' => $target->value, 'reason' => $reason],
                    userId: $actor->id
                );
            }

            return $order->load(['items', 'customer', 'statusLogs', 'photos', 'payments']);
        });
    }
}

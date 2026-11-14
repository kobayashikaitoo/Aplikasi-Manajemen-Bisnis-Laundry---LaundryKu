<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\CashTransaction;
use App\Models\Claim;
use App\Models\Notification;
use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ApprovalController extends Controller
{
    /**
     * Get list of all approval requests for Owner.
     */
    public function index(Request $request): JsonResponse
    {
        $statusFilter = $request->get('status', 'all'); // pending, approved, rejected, all
        $typeFilter = $request->get('type', 'all');     // claim, discount, cancel, all

        $items = collect();

        // 1. Klaim Pelanggan (Garansi Pakaian)
        $claims = Claim::with(['order.customer.user', 'customer.user'])
            ->orderBy('id', 'desc')
            ->get();

        foreach ($claims as $claim) {
            $mappedStatus = match ($claim->status) {
                'Diajukan', 'Ditinjau' => 'pending',
                'Disetujui', 'Selesai' => 'approved',
                'Ditolak' => 'rejected',
                default => 'pending',
            };

            $items->push([
                'id' => $claim->id,
                'source_type' => 'claim',
                'title' => 'Pengajuan Klaim: ' . ($claim->claim_type ?? 'Garansi Cucian'),
                'category_label' => 'Klaim Pelanggan',
                'order_id' => $claim->order_id,
                'order_no' => $claim->order?->order_no ?? ('#' . $claim->order_id),
                'customer_name' => $claim->customer?->name ?? 'Pelanggan',
                'requester_name' => $claim->customer?->name ?? 'Pelanggan',
                'description' => $claim->description ?? '-',
                'amount' => (int) ($claim->refund_amount ?? 0),
                'amount_label' => 'Estimasi Ganti Rugi',
                'status' => $mappedStatus,
                'status_raw' => $claim->status,
                'notes' => $claim->resolution,
                'created_at' => $claim->created_at?->toIso8601String(),
                'photos' => $claim->order?->photos()->where('photo_type', 'claim')->pluck('photo_path') ?? [],
            ]);
        }

        // 2. Orders with Diskon Khusus (> 10%) or Dibatalkan
        $specialOrders = Order::with(['customer.user', 'createdBy', 'statusLogs'])
            ->where(function ($q) {
                $q->where('discount_amount', '>', 0)
                  ->orWhere('status', 'Dibatalkan');
            })
            ->orderBy('id', 'desc')
            ->limit(30)
            ->get();

        foreach ($specialOrders as $order) {
            $isCancel = $order->status === 'Dibatalkan';
            $cancelLog = $isCancel ? $order->statusLogs->where('to_status', 'Dibatalkan')->last() : null;

            if ($isCancel) {
                $items->push([
                    'id' => 10000 + $order->id,
                    'source_type' => 'cancel',
                    'title' => 'Persetujuan Pembatalan Order #' . $order->order_no,
                    'category_label' => 'Batal Order',
                    'order_id' => $order->id,
                    'order_no' => $order->order_no,
                    'customer_name' => $order->customer?->name ?? 'Pelanggan',
                    'requester_name' => $order->createdBy?->name ?? 'Kasir',
                    'description' => $cancelLog?->reason ?? 'Pembatalan transaksi oleh kasir',
                    'amount' => (int) $order->total_amount,
                    'amount_label' => 'Nilai Order',
                    'status' => 'approved', // Cancellation is executed
                    'status_raw' => 'Dibatalkan',
                    'notes' => $cancelLog?->reason,
                    'created_at' => ($cancelLog?->created_at ?? $order->updated_at)?->toIso8601String(),
                    'photos' => [],
                ]);
            }

            if ($order->discount_amount > 0) {
                $subtotal = $order->subtotal ?: ($order->total_amount + $order->discount_amount);
                $pct = $subtotal > 0 ? round(($order->discount_amount / $subtotal) * 100) : 0;
                $isHighDiscount = $pct >= 10;

                if ($isHighDiscount) {
                    $items->push([
                        'id' => 20000 + $order->id,
                        'source_type' => 'discount',
                        'title' => "Otorisasi Diskon {$pct}% (#{$order->order_no})",
                        'category_label' => 'Diskon Khusus',
                        'order_id' => $order->id,
                        'order_no' => $order->order_no,
                        'customer_name' => $order->customer?->name ?? 'Pelanggan',
                        'requester_name' => $order->createdBy?->name ?? 'Kasir',
                        'description' => "Pengajuan potongan harga {$pct}% (Rp " . number_format($order->discount_amount, 0, ',', '.') . ")",
                        'amount' => (int) $order->discount_amount,
                        'amount_label' => 'Potongan Diskon',
                        'status' => 'approved',
                        'status_raw' => 'Disetujui',
                        'notes' => 'Otorisasi diskon oleh pemilik',
                        'created_at' => $order->created_at?->toIso8601String(),
                        'photos' => [],
                    ]);
                }
            }
        }

        // Apply filters
        $filtered = $items;
        if ($statusFilter !== 'all') {
            $filtered = $filtered->where('status', $statusFilter);
        }
        if ($typeFilter !== 'all') {
            $filtered = $filtered->where('source_type', $typeFilter);
        }

        // Counts
        $pendingCount = $items->where('status', 'pending')->count();
        $approvedCount = $items->where('status', 'approved')->count();
        $rejectedCount = $items->where('status', 'rejected')->count();

        return response()->json([
            'data' => $filtered->values()->all(),
            'meta' => [
                'total' => $filtered->count(),
                'pending_count' => $pendingCount,
                'approved_count' => $approvedCount,
                'rejected_count' => $rejectedCount,
            ]
        ]);
    }

    /**
     * Approve an approval request.
     */
    public function approve(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'notes' => 'nullable|string',
            'refund_amount' => 'nullable|integer|min:0',
            'source_type' => 'nullable|string',
        ]);

        $owner = $request->user();

        // Check if ID is a claim
        if ($id < 10000) {
            return DB::transaction(function () use ($request, $owner, $id) {
                $claim = Claim::with(['order.customer.user'])->findOrFail($id);
                $claim->status = 'Disetujui';
                $claim->resolution = $request->notes ?? 'Persetujuan disetujui oleh Pemilik.';
                if ($request->has('refund_amount')) {
                    $claim->refund_amount = (int) $request->refund_amount;
                }
                $claim->save();

                // Integrasi Kas Keluar: Otomatis buat entri pengeluaran kas jika ada ganti rugi (refund)
                if ($claim->refund_amount > 0) {
                    $branchId = $claim->order?->branch_id ?? $owner->branch_id ?? 1;
                    $claimDesc = "Kompensasi Ganti Rugi Klaim #{$claim->id} (Order #{$claim->order?->order_no})";

                    $alreadyRecorded = CashTransaction::where('branch_id', $branchId)
                        ->where('order_id', $claim->order_id)
                        ->where('category', 'claim_refund')
                        ->where('description', 'like', "%Klaim #{$claim->id}%")
                        ->exists();

                    if (!$alreadyRecorded) {
                        CashTransaction::create([
                            'branch_id' => $branchId,
                            'order_id' => $claim->order_id,
                            'user_id' => $owner->id,
                            'transaction_type' => 'out',
                            'category' => 'claim_refund',
                            'amount' => $claim->refund_amount,
                            'description' => "{$claimDesc}: " . ($claim->claim_type ?? 'Garansi Pakaian'),
                        ]);
                    }
                }

                // Log Audit
                AuditLog::create([
                    'user_id' => $owner->id,
                    'action' => 'APPROVE_CLAIM',
                    'entity_type' => 'Claim',
                    'entity_id' => $claim->id,
                    'new_values' => [
                        'status' => 'Disetujui',
                        'resolution' => $claim->resolution,
                        'refund_amount' => $claim->refund_amount,
                    ],
                    'ip_address' => $request->ip(),
                ]);

                // Notify Customer
                $customerUser = $claim->order?->customer?->user;
                if ($customerUser) {
                    Notification::create([
                        'user_id' => $customerUser->id,
                        'order_id' => $claim->order_id,
                        'type' => 'claim',
                        'title' => 'Pengajuan Klaim Disetujui',
                        'message' => "Klaim untuk pesanan #{$claim->order?->order_no} telah disetujui oleh Pemilik. " .
                            ($claim->refund_amount > 0 ? "Kompensasi sebesar Rp " . number_format($claim->refund_amount, 0, ',', '.') . " telah disiapkan." : ""),
                        'is_read' => false,
                    ]);
                }

                return response()->json([
                    'message' => 'Persetujuan klaim berhasil disetujui dan kas keluar tercatat.',
                    'data' => $claim
                ]);
            });
        }

        // For other types (cancellation, discount)
        AuditLog::create([
            'user_id' => $owner->id,
            'action' => 'APPROVE_REQUEST',
            'entity_type' => 'Approval',
            'entity_id' => $id,
            'new_values' => ['notes' => $request->notes, 'approved_at' => Carbon::now('UTC')->toIso8601String()],
            'ip_address' => $request->ip(),
        ]);

        return response()->json([
            'message' => 'Permintaan persetujuan berhasil disetujui.'
        ]);
    }

    /**
     * Reject an approval request.
     */
    public function reject(Request $request, int $id): JsonResponse
    {
        $request->validate([
            'reason' => 'required|string|min:3',
        ]);

        $owner = $request->user();

        if ($id < 10000) {
            $claim = Claim::with(['order.customer.user'])->findOrFail($id);
            $claim->status = 'Ditolak';
            $claim->resolution = 'Ditolak oleh Pemilik: ' . $request->reason;
            $claim->save();

            AuditLog::create([
                'user_id' => $owner->id,
                'action' => 'REJECT_CLAIM',
                'entity_type' => 'Claim',
                'entity_id' => $claim->id,
                'new_values' => ['status' => 'Ditolak', 'reason' => $request->reason],
                'ip_address' => $request->ip(),
            ]);

            $customerUser = $claim->order?->customer?->user;
            if ($customerUser) {
                Notification::create([
                    'user_id' => $customerUser->id,
                    'order_id' => $claim->order_id,
                    'type' => 'claim',
                    'title' => 'Pengajuan Klaim Ditolak',
                    'message' => "Klaim untuk pesanan #{$claim->order->order_no} belum dapat disetujui: {$request->reason}",
                    'is_read' => false,
                ]);
            }

            return response()->json([
                'message' => 'Pengajuan berhasil ditolak.',
                'data' => $claim
            ]);
        }

        AuditLog::create([
            'user_id' => $owner->id,
            'action' => 'REJECT_REQUEST',
            'entity_type' => 'Approval',
            'entity_id' => $id,
            'new_values' => ['reason' => $request->reason],
            'ip_address' => $request->ip(),
        ]);

        return response()->json([
            'message' => 'Permintaan persetujuan berhasil ditolak.'
        ]);
    }
}

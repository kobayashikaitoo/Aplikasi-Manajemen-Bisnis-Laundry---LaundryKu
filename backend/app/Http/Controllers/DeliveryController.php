<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Delivery;
use App\Models\Notification;
use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeliveryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Delivery::with(['order.customer.user', 'order.items', 'courier'])
            ->orderBy('id', 'desc');

        if ($user->isCourier()) {
            // Courier sees deliveries assigned to them or unassigned in their branch
            $query->where(function ($q) use ($user) {
                $q->where('courier_user_id', $user->id)
                  ->orWhereNull('courier_user_id');
            });
        } elseif ($user->isCustomer()) {
            $query->whereHas('order', function ($q) use ($user) {
                $q->where('customer_id', $user->customer?->id);
            });
        }

        if ($request->has('type') && in_array($request->type, ['pickup', 'delivery'])) {
            $query->where('type', $request->type);
        }

        if ($request->has('status') && !empty($request->status)) {
            $query->where('status', $request->status);
        }

        $deliveries = $query->paginate($request->get('per_page', 25));

        return response()->json([
            'data' => $deliveries->items(),
            'meta' => [
                'current_page' => $deliveries->currentPage(),
                'last_page' => $deliveries->lastPage(),
                'total' => $deliveries->total(),
            ]
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'order_id' => 'required|exists:orders,id',
            'courier_user_id' => 'nullable|exists:users,id',
            'type' => 'required|string|in:pickup,delivery',
            'scheduled_at' => 'nullable|date',
            'fee' => 'nullable|integer|min:0',
        ]);

        $delivery = Delivery::create([
            'order_id' => $request->order_id,
            'courier_user_id' => $request->courier_user_id ?? $request->user()->id,
            'type' => $request->type,
            'status' => 'pending',
            'scheduled_at' => $request->scheduled_at ? Carbon::parse($request->scheduled_at) : Carbon::now('UTC'),
            'fee' => (int) ($request->fee ?? 0),
        ]);

        return response()->json([
            'data' => $delivery->load(['order.customer.user', 'courier'])
        ], 201);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $delivery = Delivery::with(['order.customer.user', 'courier'])->findOrFail($id);

        $request->validate([
            'status' => 'required|string|in:pending,assigned,on_the_way,completed,cancelled',
            'notes' => 'nullable|string',
        ]);

        $oldStatus = $delivery->status;
        $delivery->status = $request->status;

        if ($request->status === 'completed' && !$delivery->completed_at) {
            $delivery->completed_at = Carbon::now('UTC');
        }

        $delivery->save();

        // Audit log
        AuditLog::create([
            'user_id' => $request->user()->id,
            'action' => 'UPDATE_DELIVERY_STATUS',
            'entity_type' => 'Delivery',
            'entity_id' => $delivery->id,
            'old_values' => ['status' => $oldStatus],
            'new_values' => ['status' => $delivery->status, 'notes' => $request->notes],
            'ip_address' => $request->ip(),
        ]);

        // Send notification to customer
        $customerUser = $delivery->order?->customer?->user;
        if ($customerUser) {
            $taskLabel = $delivery->type === 'pickup' ? 'Penjemputan' : 'Pengantaran';
            $statusLabel = match ($delivery->status) {
                'on_the_way' => 'Kurir sedang dalam perjalanan',
                'completed' => 'Telah selesai dilakukan',
                'cancelled' => 'Dibatalkan',
                default => 'Diperbarui',
            };

            Notification::create([
                'user_id' => $customerUser->id,
                'order_id' => $delivery->order_id,
                'type' => 'delivery',
                'title' => "Status {$taskLabel} Cucian",
                'message' => "Order #{$delivery->order->order_no}: {$taskLabel} {$statusLabel}.",
                'is_read' => false,
            ]);
        }

        return response()->json([
            'data' => $delivery
        ]);
    }
}

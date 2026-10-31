<?php

namespace App\Http\Controllers;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderPhoto;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    protected OrderService $orderService;

    public function __construct(OrderService $orderService)
    {
        $this->orderService = $orderService;
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Order::with(['customer', 'items.service', 'createdBy'])
            ->orderBy('created_at', 'desc');

        // RBAC: Pelanggan hanya boleh membaca order miliknya sendiri
        if ($user->isCustomer()) {
            $customerId = $user->customer?->id;
            $query->where('customer_id', $customerId);
        } elseif ($user->branch_id) {
            $query->where('branch_id', $user->branch_id);
        }

        if ($request->has('status') && $request->status !== '') {
            $query->where('status', $request->status);
        }

        if ($request->has('search') && $request->search !== '') {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('order_no', 'like', "%{$search}%")
                  ->orWhere('barcode', 'like', "%{$search}%")
                  ->orWhereHas('customer', function ($cq) use ($search) {
                      $cq->where('name', 'like', "%{$search}%")
                         ->orWhere('phone', 'like', "%{$search}%");
                  });
            });
        }

        $orders = $query->paginate($request->get('per_page', 20));

        return response()->json([
            'data' => $orders->items(),
            'meta' => [
                'current_page' => $orders->currentPage(),
                'last_page' => $orders->lastPage(),
                'total' => $orders->total(),
            ]
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'customer_id' => 'required|exists:customers,id',
            'items' => 'required|array|min:1',
            'items.*.service_id' => 'required|exists:services,id',
            'items.*.quantity' => 'required|numeric|min:0.1',
            'discount_amount' => 'nullable|integer|min:0',
            'notes' => 'nullable|string',
        ]);

        $user = $request->user();
        $idempotencyKey = $request->header('Idempotency-Key');

        // Idempotency check if order exists with this key
        if ($idempotencyKey) {
            $cacheKey = "order_idempotency_{$idempotencyKey}";
            $existingOrderId = cache()->get($cacheKey);
            if ($existingOrderId) {
                $existingOrder = Order::with(['items', 'customer', 'statusLogs', 'photos', 'payments'])
                    ->find($existingOrderId);
                if ($existingOrder) {
                    return response()->json([
                        'data' => $existingOrder
                    ]);
                }
            }
        }

        $order = $this->orderService->createOrder(
            $request->all(),
            $user,
            $idempotencyKey
        );

        if ($idempotencyKey) {
            cache()->put("order_idempotency_{$idempotencyKey}", $order->id, now()->addHours(24));
        }

        return response()->json([
            'data' => $order
        ], 201);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $order = Order::with([
            'customer.user',
            'items',
            'statusLogs.changedBy',
            'photos',
            'payments.receivedBy',
            'createdBy',
            'branch',
            'claims'
        ])->findOrFail($id);

        // RBAC check
        if ($user->isCustomer() && $order->customer_id !== $user->customer?->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Anda tidak memiliki hak akses untuk melihat order ini.',
                ]
            ], 403);
        }

        return response()->json([
            'data' => $order
        ]);
    }

    public function timeline(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $order = Order::findOrFail($id);

        if ($user->isCustomer() && $order->customer_id !== $user->customer?->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Anda tidak memiliki hak akses untuk melihat linimasa order ini.',
                ]
            ], 403);
        }

        $logs = $order->statusLogs()
            ->with('changedBy')
            ->orderBy('created_at', 'asc')
            ->get();

        return response()->json([
            'data' => $logs
        ]);
    }

    public function uploadPhoto(Request $request, int $id): JsonResponse
    {
        $order = Order::findOrFail($id);

        $request->validate([
            'photo' => 'required',
            'photo_type' => 'nullable|string|in:initial,progress,completed',
        ]);

        $user = $request->user();
        $photoType = $request->photo_type ?? 'initial';

        // Support both multipart file upload and base64 string
        if ($request->hasFile('photo')) {
            $path = $request->file('photo')->store('order_photos', 'public');
            $photoUrl = "/storage/" . $path;
        } elseif (is_string($request->photo)) {
            // Base64 or mock image path
            $photoData = $request->photo;
            if (str_starts_with($photoData, 'data:image')) {
                $imageParts = explode(';base64,', $photoData);
                $imageBase64 = base64_decode($imageParts[1]);
                $fileName = 'order_photos/' . uniqid('photo_') . '.jpg';
                Storage::disk('public')->put($fileName, $imageBase64);
                $photoUrl = "/storage/" . $fileName;
            } else {
                $photoUrl = $photoData;
            }
        } else {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_PHOTO',
                    'message' => 'Format foto tidak valid.',
                ]
            ], 422);
        }

        $orderPhoto = OrderPhoto::create([
            'order_id' => $order->id,
            'photo_path' => $photoUrl,
            'photo_type' => $photoType,
            'uploaded_by_user_id' => $user->id,
        ]);

        return response()->json([
            'data' => $orderPhoto
        ], 201);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $order = Order::findOrFail($id);

        $request->validate([
            'status' => 'required|string',
            'reason' => 'nullable|string',
        ]);

        try {
            $targetStatus = OrderStatus::from($request->status);
        } catch (\ValueError) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_TRANSITION',
                    'message' => "Status '{$request->status}' tidak dikenal dalam siklus order.",
                ]
            ], 422);
        }

        $user = $request->user();

        try {
            $updatedOrder = $this->orderService->transition(
                $order,
                $targetStatus,
                $user,
                $request->reason
            );

            return response()->json([
                'data' => $updatedOrder
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_TRANSITION',
                    'message' => $e->validator->errors()->first(),
                ]
            ], 422);
        }
    }
}

<?php

namespace App\Http\Controllers;

use App\Models\CashTransaction;
use App\Models\Claim;
use App\Models\Notification;
use App\Models\Order;
use App\Models\OrderPhoto;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ClaimController extends Controller
{
    public function store(Request $request, int $orderId): JsonResponse
    {
        $user = $request->user();
        $order = Order::with('customer')->findOrFail($orderId);

        // RBAC: Pelanggan hanya bisa mengajukan klaim untuk order miliknya sendiri
        if ($user->isCustomer() && $order->customer_id !== $user->customer?->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Anda tidak memiliki hak akses untuk mengajukan klaim pada order ini.',
                ]
            ], 403);
        }

        // Validasi: Status pesanan harus sudah 'Selesai'
        if ($order->status !== 'Selesai') {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_STATUS',
                    'message' => 'Pengajuan klaim hanya dapat dilakukan untuk pesanan yang telah berstatus Selesai.',
                ]
            ], 422);
        }

        // Validasi: Hanya boleh satu klaim per pesanan
        $existingClaim = Claim::where('order_id', $order->id)->first();
        if ($existingClaim) {
            return response()->json([
                'error' => [
                    'code' => 'CLAIM_EXISTS',
                    'message' => 'Klaim untuk pesanan ini sudah pernah diajukan dengan status: ' . $existingClaim->status,
                ]
            ], 422);
        }

        // Validasi: Batas waktu masa klaim (7 hari setelah selesai)
        if ($order->completed_at) {
            $deadline = \Carbon\Carbon::parse($order->completed_at)->addDays(7);
            if (now()->greaterThan($deadline)) {
                return response()->json([
                    'error' => [
                        'code' => 'CLAIM_EXPIRED',
                        'message' => 'Masa pengajuan klaim telah habis (maksimal 7 hari setelah pesanan selesai).',
                    ]
                ], 422);
            }
        }

        $request->validate([
            'claim_type' => 'required|string|max:100',
            'description' => 'required|string',
            'photos' => 'nullable|array',
            'photos.*' => 'required|string',
        ]);

        return DB::transaction(function () use ($request, $order, $user) {
            // Buat record klaim baru
            $claim = Claim::create([
                'order_id' => $order->id,
                'customer_id' => $order->customer_id,
                'claim_type' => $request->claim_type,
                'description' => $request->description,
                'status' => 'Diajukan',
                'resolution' => null,
                'refund_amount' => 0,
            ]);

            // Simpan foto-foto pendukung jika ada
            if ($request->has('photos') && is_array($request->photos)) {
                foreach ($request->photos as $photoData) {
                    $photoUrl = $this->storePhoto($photoData);
                    if ($photoUrl) {
                        OrderPhoto::create([
                            'order_id' => $order->id,
                            'photo_path' => $photoUrl,
                            'photo_type' => 'claim',
                            'uploaded_by_user_id' => $user->id,
                        ]);
                    }
                }
            }

            // Notifikasi otomatis ke akun pelanggan
            Notification::create([
                'user_id' => $user->id,
                'order_id' => $order->id,
                'type' => 'claim',
                'title' => 'Pengajuan Klaim Berhasil',
                'message' => "Klaim untuk order #{$order->order_no} berhasil diajukan dan sedang menunggu peninjauan tim kami.",
            ]);

            $claimPhotos = OrderPhoto::where('order_id', $order->id)
                ->where('photo_type', 'claim')
                ->get();

            return response()->json([
                'data' => [
                    'id' => $claim->id,
                    'order_id' => $claim->order_id,
                    'customer_id' => $claim->customer_id,
                    'claim_type' => $claim->claim_type,
                    'description' => $claim->description,
                    'status' => $claim->status,
                    'resolution' => $claim->resolution,
                    'refund_amount' => $claim->refund_amount,
                    'photos' => $claimPhotos,
                    'created_at' => $claim->created_at?->toIso8601String(),
                ]
            ], 201);
        });
    }

    public function show(Request $request, int $orderId): JsonResponse
    {
        $user = $request->user();
        $order = Order::findOrFail($orderId);

        if ($user->isCustomer() && $order->customer_id !== $user->customer?->id) {
            return response()->json([
                'error' => [
                    'code' => 'FORBIDDEN',
                    'message' => 'Anda tidak memiliki hak akses untuk melihat klaim order ini.',
                ]
            ], 403);
        }

        $claim = Claim::where('order_id', $orderId)->latest()->first();
        if (!$claim) {
            return response()->json([
                'data' => null
            ]);
        }

        $photos = OrderPhoto::where('order_id', $orderId)
            ->where('photo_type', 'claim')
            ->get();

        return response()->json([
            'data' => [
                'id' => $claim->id,
                'order_id' => $claim->order_id,
                'customer_id' => $claim->customer_id,
                'claim_type' => $claim->claim_type,
                'description' => $claim->description,
                'status' => $claim->status,
                'resolution' => $claim->resolution,
                'refund_amount' => $claim->refund_amount,
                'photos' => $photos,
                'created_at' => $claim->created_at?->toIso8601String(),
            ]
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Claim::with(['order.customer', 'customer'])->orderBy('created_at', 'desc');

        if ($user->isCustomer()) {
            $query->where('customer_id', $user->customer?->id);
        } elseif ($user->branch_id) {
            $query->whereHas('order', function ($q) use ($user) {
                $q->where('branch_id', $user->branch_id);
            });
        }

        $claims = $query->paginate($request->get('per_page', 20));

        return response()->json([
            'data' => $claims->items(),
            'meta' => [
                'current_page' => $claims->currentPage(),
                'last_page' => $claims->lastPage(),
                'total' => $claims->total(),
            ]
        ]);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $claim = Claim::with('order.customer.user')->findOrFail($id);

        $request->validate([
            'status' => 'required|string|in:Ditinjau,Disetujui,Ditolak,Selesai',
            'resolution' => 'nullable|string',
            'refund_amount' => 'nullable|integer|min:0',
        ]);

        return DB::transaction(function () use ($request, $claim) {
            $user = $request->user();
            $claim->status = $request->status;
            if ($request->has('resolution')) {
                $claim->resolution = $request->resolution;
            }
            if ($request->has('refund_amount')) {
                $claim->refund_amount = (int) $request->refund_amount;
            }
            $claim->save();

            // Integrasi Kas Keluar: Otomatis tulis entri pengeluaran kas jika ada ganti rugi (refund)
            if (in_array($claim->status, ['Disetujui', 'Selesai']) && $claim->refund_amount > 0) {
                $branchId = $claim->order?->branch_id ?? $user->branch_id ?? 1;
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
                        'user_id' => $user->id,
                        'transaction_type' => 'out',
                        'category' => 'claim_refund',
                        'amount' => $claim->refund_amount,
                        'description' => "{$claimDesc}: " . ($claim->claim_type ?? 'Garansi Pakaian'),
                    ]);
                }
            }

            // Kirim notifikasi update status ke pelanggan
            $customerUser = $claim->order?->customer?->user;
            if ($customerUser) {
                Notification::create([
                    'user_id' => $customerUser->id,
                    'order_id' => $claim->order_id,
                    'type' => 'claim',
                    'title' => 'Update Status Klaim',
                    'message' => "Klaim pesanan #{$claim->order?->order_no} status saat ini: {$claim->status}." .
                        ($claim->resolution ? " Catatan: {$claim->resolution}" : '') .
                        ($claim->refund_amount > 0 ? " Kompensasi: Rp " . number_format($claim->refund_amount, 0, ',', '.') : ''),
                ]);
            }

            return response()->json([
                'data' => $claim
            ]);
        });
    }

    private function storePhoto(string $photoData): ?string
    {
        if (str_starts_with($photoData, 'data:image')) {
            $imageParts = explode(';base64,', $photoData);
            if (isset($imageParts[1])) {
                $imageBase64 = base64_decode($imageParts[1]);
                $fileName = 'order_photos/' . uniqid('claim_') . '.jpg';
                Storage::disk('public')->put($fileName, $imageBase64);
                return '/storage/' . $fileName;
            }
        }
        return $photoData;
    }
}

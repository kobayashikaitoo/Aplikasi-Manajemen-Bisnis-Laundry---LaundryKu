<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Role;
use App\Models\Customer;
use App\Models\Branch;
use App\Services\JwtService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    protected JwtService $jwtService;

    public function __construct(JwtService $jwtService)
    {
        $this->jwtService = $jwtService;
    }

    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::with(['role', 'branch', 'customer'])->where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_CREDENTIALS',
                    'message' => 'Email atau kata sandi tidak cocok.',
                ]
            ], 401);
        }

        if (!$user->is_active) {
            return response()->json([
                'error' => [
                    'code' => 'ACCOUNT_INACTIVE',
                    'message' => 'Akun Anda dinonaktifkan.',
                ]
            ], 403);
        }

        $token = $this->jwtService->generateToken($user);

        return response()->json([
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'role' => $user->role?->name,
                    'branch_id' => $user->branch_id,
                    'customer_id' => $user->customer?->id,
                    'point_balance' => $user->customer?->point_balance ?? 0,
                ],
            ]
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load(['role', 'branch', 'customer']);

        return response()->json([
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'role' => $user->role?->name,
                'branch_id' => $user->branch_id,
                'customer_id' => $user->customer?->id,
                'point_balance' => $user->customer?->point_balance ?? 0,
                'address' => $user->customer?->address ?? '',
            ]
        ]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();

        $request->validate([
            'name' => 'required|string|max:255',
            'phone' => 'nullable|string|max:30',
            'address' => 'nullable|string|max:500',
        ]);

        $user->name = $request->name;
        if ($request->has('phone')) {
            $user->phone = $request->phone;
        }
        $user->save();

        if ($user->customer) {
            $user->customer->name = $user->name;
            $user->customer->phone = $user->phone;
            if ($request->has('address')) {
                $user->customer->address = $request->address;
            }
            $user->customer->save();
        }

        return response()->json([
            'data' => [
                'message' => 'Profil berhasil diperbarui.',
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'role' => $user->role?->name,
                    'branch_id' => $user->branch_id,
                    'customer_id' => $user->customer?->id,
                    'point_balance' => $user->customer?->point_balance ?? 0,
                    'address' => $user->customer?->address ?? '',
                ]
            ]
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();

        $request->validate([
            'current_password' => 'required|string',
            'password' => 'required|string|min:8|confirmed',
        ]);

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'error' => [
                    'code' => 'INVALID_PASSWORD',
                    'message' => 'Kata sandi lama Anda salah.',
                ]
            ], 422);
        }

        $user->password = $request->password;
        $user->save();

        return response()->json([
            'data' => [
                'message' => 'Kata sandi berhasil diubah.',
            ]
        ]);
    }

    public function updateAddress(Request $request): JsonResponse
    {
        $user = $request->user()->load('customer');

        $request->validate([
            'address' => 'required|string|max:500',
        ]);

        if ($user->customer) {
            $user->customer->address = $request->address;
            $user->customer->save();
        }

        return response()->json([
            'data' => [
                'message' => 'Alamat berhasil disimpan.',
                'address' => $user->customer?->address ?? '',
            ]
        ]);
    }

    public function deleteAccount(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->is_active = false;
        $user->save();

        return response()->json([
            'data' => [
                'message' => 'Akun Anda berhasil dinonaktifkan.',
            ]
        ]);
    }

    public function register(Request $request): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:8',
            'phone' => 'nullable|string|max:30',
            'address' => 'nullable|string|max:500',
        ]);

        // Pendaftaran saat ini dikhususkan hanya untuk role pelanggan
        $role = Role::where('name', 'pelanggan')->first();
        if (!$role) {
            $role = Role::create(['name' => 'pelanggan', 'guard_name' => 'api']);
        }

        // Bersihkan role kurir jika sebelumnya sempat dibuat
        Role::where('name', 'kurir')->delete();

        $branch = Branch::where('is_active', true)->first() ?? Branch::first();

        $user = User::create([
            'role_id' => $role->id,
            'branch_id' => $branch?->id,
            'name' => $request->name,
            'email' => $request->email,
            'phone' => $request->phone ?? '',
            'password' => $request->password,
            'is_active' => true,
        ]);

        $count = Customer::count() + 1;
        $customerCode = 'CUST-' . str_pad((string)$count, 3, '0', STR_PAD_LEFT);
        $customer = Customer::create([
            'code' => $customerCode,
            'user_id' => $user->id,
            'branch_id' => $branch?->id,
            'name' => $user->name,
            'phone' => $user->phone,
            'address' => $request->address ?? '',
            'point_balance' => 0,
        ]);

        $token = $this->jwtService->generateToken($user);

        return response()->json([
            'data' => [
                'message' => 'Pendaftaran akun pelanggan berhasil.',
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'role' => 'pelanggan',
                    'branch_id' => $user->branch_id,
                    'customer_id' => $customer->id,
                    'point_balance' => $customer->point_balance,
                ],
            ]
        ], 201);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email|exists:users,email',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json([
                'error' => [
                    'code' => 'USER_NOT_FOUND',
                    'message' => 'Pengguna dengan surel tersebut tidak ditemukan.',
                ]
            ], 404);
        }

        $user->password = $request->password;
        $user->save();

        return response()->json([
            'data' => [
                'message' => 'Kata sandi berhasil diatur ulang. Silakan masuk dengan kata sandi baru Anda.',
            ]
        ]);
    }
}

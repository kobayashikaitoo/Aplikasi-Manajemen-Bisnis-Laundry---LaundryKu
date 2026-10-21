<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StaffController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $currentUser = $request->user();
        
        $staff = User::with('role')
            ->whereHas('role', function ($q) {
                $q->where('name', 'pegawai');
            })
            ->when($currentUser->branch_id, function ($q, $branchId) {
                $q->where('branch_id', $branchId);
            })
            ->orderBy('id', 'desc')
            ->get();

        return response()->json([
            'data' => $staff->map(function ($u) {
                return [
                    'id' => $u->id,
                    'name' => $u->name,
                    'email' => $u->email,
                    'phone' => $u->phone,
                    'role' => $u->role?->name ?? 'pegawai',
                    'branch_id' => $u->branch_id,
                    'is_active' => (bool)$u->is_active,
                    'created_at' => $u->created_at?->toIso8601String(),
                ];
            })
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:8',
            'phone' => 'nullable|string|max:30',
        ]);

        $currentUser = $request->user();
        $rolePegawai = Role::firstOrCreate(['name' => 'pegawai'], ['guard_name' => 'api']);

        $user = User::create([
            'role_id' => $rolePegawai->id,
            'branch_id' => $currentUser->branch_id,
            'name' => $request->name,
            'email' => $request->email,
            'phone' => $request->phone ?? '',
            'password' => $request->password,
            'is_active' => true,
        ]);

        AuditLog::create([
            'user_id' => $currentUser->id,
            'action' => 'CREATE_STAFF',
            'entity_type' => 'User',
            'entity_id' => $user->id,
            'new_values' => [
                'name' => $user->name,
                'email' => $user->email,
                'role' => 'pegawai',
            ],
            'ip_address' => $request->ip(),
        ]);

        return response()->json([
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'role' => 'pegawai',
                'branch_id' => $user->branch_id,
                'is_active' => (bool)$user->is_active,
                'created_at' => $user->created_at?->toIso8601String(),
            ]
        ], 201);
    }

    public function toggleStatus(Request $request, int $id): JsonResponse
    {
        $currentUser = $request->user();
        $user = User::whereHas('role', function ($q) {
            $q->where('name', 'pegawai');
        })->findOrFail($id);

        $oldStatus = $user->is_active;
        $user->is_active = !$oldStatus;
        $user->save();

        AuditLog::create([
            'user_id' => $currentUser->id,
            'action' => 'TOGGLE_STAFF_STATUS',
            'entity_type' => 'User',
            'entity_id' => $user->id,
            'old_values' => ['is_active' => $oldStatus],
            'new_values' => ['is_active' => $user->is_active],
            'ip_address' => $request->ip(),
        ]);

        return response()->json([
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'is_active' => (bool)$user->is_active,
                'message' => $user->is_active
                    ? 'Akun pegawai berhasil diaktifkan.'
                    : 'Akun pegawai berhasil dinonaktifkan.',
            ]
        ]);
    }
}

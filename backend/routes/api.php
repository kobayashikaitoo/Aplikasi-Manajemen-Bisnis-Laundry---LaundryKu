<?php

use App\Http\Controllers\AuditLogController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CashTransactionController;
use App\Http\Controllers\CustomerController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\ServiceController;
use App\Http\Controllers\StaffController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes for LaundryKu (Prefix /api/v1)
|--------------------------------------------------------------------------
*/

// Public routes
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword']);

// Authenticated routes
Route::middleware(['auth.jwt'])->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::put('/auth/profile', [AuthController::class, 'updateProfile']);
    Route::post('/auth/change-password', [AuthController::class, 'changePassword']);
    Route::put('/auth/address', [AuthController::class, 'updateAddress']);
    Route::delete('/auth/account', [AuthController::class, 'deleteAccount']);

    // Services (Read for all, Write for Pemilik)
    Route::get('/services', [ServiceController::class, 'index']);
    Route::middleware(['role:pemilik'])->group(function () {
        Route::post('/services', [ServiceController::class, 'store']);
        Route::patch('/services/{id}', [ServiceController::class, 'update']);
    });

    // Customers list & points
    Route::get('/customers', [CustomerController::class, 'index'])->middleware(['role:pemilik,pegawai']);
    Route::get('/customers/{id}/points', [CustomerController::class, 'getPoints']);
    Route::post('/customers/{id}/redeem-points', [CustomerController::class, 'redeemPoints']);

    // Orders
    Route::get('/orders', [OrderController::class, 'index']);
    Route::get('/orders/{id}', [OrderController::class, 'show']);
    Route::get('/orders/{id}/timeline', [OrderController::class, 'timeline']);

    Route::middleware(['role:pegawai,pemilik'])->group(function () {
        Route::post('/orders', [OrderController::class, 'store']);
        Route::post('/orders/{id}/photos', [OrderController::class, 'uploadPhoto']);
        Route::patch('/orders/{id}/status', [OrderController::class, 'updateStatus']);
        Route::post('/orders/{id}/payments', [PaymentController::class, 'store']);
    });

    // Cash Transactions / Expenses (Pemilik only)
    Route::post('/cash-transactions', [CashTransactionController::class, 'store'])->middleware(['role:pemilik']);

    // Reports & Staff Management (Pemilik only)
    Route::middleware(['role:pemilik'])->group(function () {
        Route::get('/reports/dashboard', [ReportController::class, 'dashboard']);
        Route::get('/reports/cashflow', [ReportController::class, 'cashflow']);
        Route::get('/reports/demo-queries', [ReportController::class, 'demoQueries']);
        Route::get('/audit-logs', [AuditLogController::class, 'index']);

        // Kelola Pegawai / Kasir
        Route::get('/staff', [StaffController::class, 'index']);
        Route::post('/staff', [StaffController::class, 'store']);
        Route::patch('/staff/{id}/toggle-status', [StaffController::class, 'toggleStatus']);
    });

    // Notifications (Customer & All)
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::patch('/notifications/{id}/read', [NotificationController::class, 'markAsRead']);
});

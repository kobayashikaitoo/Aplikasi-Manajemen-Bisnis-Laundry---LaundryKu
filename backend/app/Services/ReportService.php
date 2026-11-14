<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\CashTransaction;
use App\Models\Customer;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ReportService
{
    /**
     * Dashboard overview for owner.
     */
    public function getDashboardSummary(int $branchId): array
    {
        $todayStart = Carbon::today('UTC');
        $todayEnd = Carbon::tomorrow('UTC');

        // Omzet hari ini (dari payments)
        $omzetToday = (int) Payment::whereHas('order', function ($q) use ($branchId) {
            $q->where('branch_id', $branchId);
        })
        ->whereBetween('created_at', [$todayStart, $todayEnd])
        ->sum('amount');

        // Order baru hari ini
        $orderCountToday = Order::where('branch_id', $branchId)
            ->whereBetween('created_at', [$todayStart, $todayEnd])
            ->count();

        // Order per status
        $statusCounts = Order::where('branch_id', $branchId)
            ->select('status', DB::raw('count(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();

        // Order aktif (sedang proses)
        $activeStatuses = [
            OrderStatus::Diterima->value,
            OrderStatus::Ditimbang->value,
            OrderStatus::Dicuci->value,
            OrderStatus::Disetrika->value,
            OrderStatus::Siap->value,
        ];
        $activeOrdersCount = Order::where('branch_id', $branchId)
            ->whereIn('status', $activeStatuses)
            ->count();

        // Query demo 3: Order Siap mendekati due_at (< 2 hari)
        $nearDueOrders = Order::with('customer')
            ->where('branch_id', $branchId)
            ->where('status', OrderStatus::Siap->value)
            ->whereNotNull('due_at')
            ->where('due_at', '<=', Carbon::now('UTC')->addDays(2))
            ->orderBy('due_at', 'asc')
            ->get();

        // Kas operasional hari ini
        $cashInToday = (int) CashTransaction::where('branch_id', $branchId)
            ->where('transaction_type', 'in')
            ->whereBetween('created_at', [$todayStart, $todayEnd])
            ->sum('amount');

        $cashOutToday = (int) CashTransaction::where('branch_id', $branchId)
            ->where('transaction_type', 'out')
            ->whereBetween('created_at', [$todayStart, $todayEnd])
            ->sum('amount');

        // Total saldo kas berjalan
        $totalCashIn = (int) CashTransaction::where('branch_id', $branchId)
            ->where('transaction_type', 'in')
            ->sum('amount');

        $totalCashOut = (int) CashTransaction::where('branch_id', $branchId)
            ->where('transaction_type', 'out')
            ->sum('amount');

        $currentBalance = $totalCashIn - $totalCashOut;

        return [
            'today' => [
                'omzet' => $omzetToday,
                'order_count' => $orderCountToday,
                'cash_in' => $cashInToday,
                'cash_out' => $cashOutToday,
                'net_cash' => $cashInToday - $cashOutToday,
            ],
            'active_orders_count' => $activeOrdersCount,
            'current_balance' => $currentBalance,
            'status_counts' => $statusCounts,
            'near_due_orders' => $nearDueOrders,
            'analytics' => $this->getDemoQueries($branchId),
        ];
    }

    /**
     * Cashflow statement grouped by date.
     */
    public function getCashflow(int $branchId, ?string $startDate = null, ?string $endDate = null): array
    {
        $start = $startDate ? Carbon::parse($startDate)->startOfDay() : Carbon::now('UTC')->subDays(30)->startOfDay();
        $end = $endDate ? Carbon::parse($endDate)->endOfDay() : Carbon::now('UTC')->endOfDay();

        $transactions = CashTransaction::where('branch_id', $branchId)
            ->whereBetween('created_at', [$start, $end])
            ->orderBy('created_at', 'desc')
            ->get();

        $totalIn = (int) $transactions->where('transaction_type', 'in')->sum('amount');
        $totalOut = (int) $transactions->where('transaction_type', 'out')->sum('amount');

        return [
            'summary' => [
                'total_in' => $totalIn,
                'total_out' => $totalOut,
                'net' => $totalIn - $totalOut,
            ],
            'transactions' => $transactions,
        ];
    }

    /**
     * Demo Queries (PRD 7.2).
     */
    public function getDemoQueries(int $branchId): array
    {
        $now = Carbon::now('UTC');

        // 1. Omzet harian dalam 7 hari terakhir (dipastikan berurutan 7 hari penuh)
        $sevenDaysAgo = $now->copy()->subDays(6)->startOfDay();
        $dailyRecords = CashTransaction::where('branch_id', $branchId)
            ->where('transaction_type', 'in')
            ->where('created_at', '>=', $sevenDaysAgo)
            ->select(DB::raw('DATE(created_at) as date'), DB::raw('SUM(amount) as omzet'))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->pluck('omzet', 'date')
            ->toArray();

        $dailyOmzet = [];
        for ($i = 6; $i >= 0; $i--) {
            $d = $now->copy()->subDays($i)->format('Y-m-d');
            $dailyOmzet[] = [
                'date' => $d,
                'omzet' => (int) ($dailyRecords[$d] ?? 0),
            ];
        }

        // 2. Jumlah order per status saat ini
        $ordersPerStatus = Order::where('branch_id', $branchId)
            ->select('status', DB::raw('count(*) as count'))
            ->groupBy('status')
            ->get();

        // 3. Order berstatus Siap yang due_at kurang dari 2 hari
        $siapNearDue = Order::with('customer')
            ->where('branch_id', $branchId)
            ->where('status', OrderStatus::Siap->value)
            ->whereNotNull('due_at')
            ->where('due_at', '<=', $now->copy()->addDays(2))
            ->get();

        // 4. Pelanggan tanpa order dalam 30 hari terakhir
        $thirtyDaysAgo = $now->copy()->subDays(30);
        $inactiveCustomers = Customer::where('branch_id', $branchId)
            ->whereDoesntHave('orders', function ($q) use ($thirtyDaysAgo) {
                $q->where('created_at', '>=', $thirtyDaysAgo);
            })
            ->get();

        // 5. Pendapatan per jenis layanan
        $revenuePerService = OrderItem::whereHas('order', function ($q) use ($branchId) {
            $q->where('branch_id', $branchId)
              ->whereNotIn('status', [OrderStatus::Dibatalkan->value]);
        })
        ->select('service_name_snap', DB::raw('SUM(subtotal) as total_revenue'), DB::raw('SUM(quantity) as total_quantity'))
        ->groupBy('service_name_snap')
        ->orderBy('total_revenue', 'desc')
        ->get()
        ->map(function ($item) {
            return [
                'service_name_snap' => $item->service_name_snap,
                'total_revenue' => (int) $item->total_revenue,
                'total_quantity' => (float) $item->total_quantity,
            ];
        });

        return [
            'q1_daily_omzet_7d' => $dailyOmzet,
            'q2_orders_per_status' => $ordersPerStatus,
            'q3_siap_near_due' => $siapNearDue,
            'q4_inactive_customers_30d' => $inactiveCustomers,
            'q5_revenue_per_service' => $revenuePerService,
        ];
    }
}

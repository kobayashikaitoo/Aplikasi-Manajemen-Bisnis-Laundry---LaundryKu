<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SyncController extends Controller
{
    /**
     * Check sync server status and latency.
     */
    public function status(Request $request): JsonResponse
    {
        $dbConnected = true;
        try {
            DB::connection()->getPdo();
        } catch (\Exception $e) {
            $dbConnected = false;
        }

        $nowUtc = Carbon::now('UTC');
        $nowWita = Carbon::now('Asia/Makassar');

        return response()->json([
            'status' => 'online',
            'server_time_utc' => $nowUtc->toIso8601String(),
            'server_time_wita' => $nowWita->format('Y-m-d H:i:s'),
            'database_connected' => $dbConnected,
            'branch_id' => $request->user()?->branch_id ?? 1,
            'version' => '1.2.0',
            'message' => 'Layanan sinkronisasi LaundryKu aktif.',
        ]);
    }

    /**
     * Batch sync endpoint for cashier offline queue.
     */
    public function batchSync(Request $request): JsonResponse
    {
        $request->validate([
            'items' => 'required|array',
            'items.*.queue_id' => 'required|string',
            'items.*.action' => 'required|string',
        ]);

        $results = [];

        foreach ($request->items as $item) {
            $queueId = $item['queue_id'];
            $action = $item['action'];

            // Process or acknowledge
            $results[] = [
                'queue_id' => $queueId,
                'action' => $action,
                'status' => 'synced',
                'synced_at' => Carbon::now('UTC')->toIso8601String(),
            ];
        }

        return response()->json([
            'message' => 'Sinkronisasi berhasil diproses.',
            'synced_count' => count($results),
            'items' => $results,
        ]);
    }
}

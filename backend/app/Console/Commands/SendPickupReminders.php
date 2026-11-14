<?php

namespace App\Console\Commands;

use App\Enums\OrderStatus;
use App\Models\Notification;
use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Artisan command: laundry:reminders
 *
 * Kirim notifikasi pengingat in-app kepada pelanggan yang cuciannya
 * sudah berstatus "Siap" tetapi belum diambil dan mendekati batas waktu.
 *
 * Jadwal: dijalankan setiap hari pukul 08:00 WITA (00:00 UTC)
 * via Schedule di routes/console.php.
 *
 * TIDAK menggunakan API berbayar, Firebase, atau layanan eksternal.
 * Notifikasi ditulis langsung ke tabel `notifications` (MySQL lokal).
 */
class SendPickupReminders extends Command
{
    /**
     * Nama signature command artisan.
     */
    protected $signature = 'laundry:reminders';

    /**
     * Deskripsi singkat command.
     */
    protected $description = 'Kirim notifikasi in-app pengingat batas ambil cucian kepada pelanggan (status Siap, due_at mendekati)';

    public function handle(): int
    {
        $now = Carbon::now('UTC');

        // Kirim 2 gelombang pengingat:
        // Gelombang 1 — due_at dalam 2 hari ke depan (peringatan dini)
        // Gelombang 2 — due_at dalam 1 hari ke depan (peringatan mendesak)
        $thresholds = [
            ['days' => 2, 'label' => 'peringatan_dini',     'urgent' => false],
            ['days' => 1, 'label' => 'peringatan_mendesak', 'urgent' => true],
        ];

        $totalSent = 0;
        $totalSkipped = 0;

        foreach ($thresholds as $threshold) {
            $windowStart = $now->copy();
            $windowEnd   = $now->copy()->addDays($threshold['days'])->endOfDay();

            // Ambil order berstatus Siap dengan due_at dalam window
            $orders = Order::with(['customer.user'])
                ->where('status', OrderStatus::Siap->value)
                ->whereNotNull('due_at')
                ->whereBetween('due_at', [$windowStart, $windowEnd])
                ->get();

            foreach ($orders as $order) {
                // Pastikan pelanggan punya akun user (supaya notifikasi bisa dikirim)
                $customerUser = $order->customer?->user;
                if (!$customerUser) {
                    $totalSkipped++;
                    continue;
                }

                // Cegah duplikasi: cek apakah notif tipe ini sudah dikirim hari ini
                $alreadySent = Notification::where('user_id', $customerUser->id)
                    ->where('order_id', $order->id)
                    ->where('type', 'pickup_reminder')
                    ->whereDate('created_at', $now->toDateString())
                    ->exists();

                if ($alreadySent) {
                    $totalSkipped++;
                    continue;
                }

                // Hitung sisa hari dengan pembulatan hari penuh
                $daysLeft = (int) ceil($now->diffInHours($order->due_at) / 24);
                $daysLeft = max(0, $daysLeft);

                $title   = $threshold['urgent']
                    ? '⚠️ Segera Ambil Cucian Anda!'
                    : '🧺 Pengingat: Cucian Sudah Siap';

                $message = $threshold['urgent']
                    ? "Order #{$order->order_no} harus diambil dalam {$daysLeft} hari lagi (batas: "
                      . $order->due_at->setTimezone('Asia/Makassar')->format('d M Y H:i')
                      . " WITA). Lewat batas, cucian tidak dapat dijamin tersedia."
                    : "Order #{$order->order_no} sudah selesai diproses dan menunggu pengambilan. "
                      . "Sisa waktu: {$daysLeft} hari (batas: "
                      . $order->due_at->setTimezone('Asia/Makassar')->format('d M Y')
                      . " WITA).";

                // Tulis notifikasi ke database (tidak ada API eksternal)
                DB::transaction(function () use ($customerUser, $order, $title, $message) {
                    Notification::create([
                        'user_id'  => $customerUser->id,
                        'order_id' => $order->id,
                        'type'     => 'pickup_reminder',
                        'title'    => $title,
                        'message'  => $message,
                        'is_read'  => false,
                    ]);
                });

                $totalSent++;
                $this->line("  ✓ Notif dikirim → {$customerUser->name} | Order #{$order->order_no} | Sisa {$daysLeft} hari");
            }
        }

        $this->info("laundry:reminders selesai — {$totalSent} notifikasi terkirim, {$totalSkipped} dilewati (duplikat / tanpa akun).");

        Log::info('laundry:reminders', [
            'run_at'        => $now->toIso8601String(),
            'total_sent'    => $totalSent,
            'total_skipped' => $totalSkipped,
        ]);

        return self::SUCCESS;
    }
}

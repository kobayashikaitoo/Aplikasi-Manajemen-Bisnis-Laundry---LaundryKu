<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

/*
|--------------------------------------------------------------------------
| LaundryKu — Scheduled Commands
|--------------------------------------------------------------------------
|
| Untuk mengaktifkan scheduler di production, tambahkan satu baris
| cron job ini di server (cPanel / VPS / Shared Hosting):
|
|   * * * * * cd /path-to-project && php artisan schedule:run >> /dev/null 2>&1
|
| Di Laragon (lokal / development), jalankan manual kapanpun:
|   php artisan laundry:reminders
|   php artisan schedule:run
|
*/

// Kirim notifikasi in-app pengingat batas ambil cucian (status Siap, due_at mendekati)
// Jalan otomatis setiap hari pukul 08:00 WITA = 00:00 UTC
// Tidak butuh Firebase, FCM, API berbayar — hanya tulis ke tabel notifications (MySQL)
Schedule::command('laundry:reminders')
    ->dailyAt('00:00')       // 08:00 WITA = 00:00 UTC
    ->withoutOverlapping()   // Cegah jalan ganda jika proses sebelumnya belum selesai
    ->runInBackground();     // Tidak memblokir proses scheduler lain

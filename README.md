# LaundryKu — Aplikasi Manajemen Bisnis Laundry

Aplikasi manajemen bisnis laundry berbasis **mobile (Flutter)** dengan **backend REST API (Laravel)**. Mendukung multi-peran (Pemilik, Pegawai, Pelanggan), siklus pesanan lengkap dengan *state machine*, pembayaran atomik, poin loyalitas, pencatatan kas, audit log, dan notifikasi.

> Proyek kuliah — Semester 5, Pemrograman Mobile.

---

## Daftar Isi

- [Tech Stack](#tech-stack)
- [Fitur Utama](#fitur-utama)
- [Struktur Repo](#struktur-repo)
- [Prasyarat](#prasyarat)
- [Cara Menjalankan Backend](#cara-menjalankan-backend)
- [Cara Menjalankan Aplikasi Flutter](#cara-menjalankan-aplikasi-flutter)
- [Membangun APK](#membangun-apk)
- [Konfigurasi Base URL API](#konfigurasi-base-url-api)
- [Akun Demo](#akun-demo)
- [Pengujian End-to-End](#pengujian-end-to-end)
- [Aturan Bisnis Penting](#aturan-bisnis-penting)
- [Troubleshooting](#troubleshooting)

---

## Tech Stack

| Lapisan | Teknologi |
|---|---|
| **Backend** | PHP 8.3, Laravel 11, MySQL 8, JWT (token bearer) |
| **Mobile** | Flutter 3.x (Dart), Riverpod (state management), Dio (HTTP) |
| **Fitur mobile** | qr_flutter (QR nota), mobile_scanner (pindai QR), image_picker (foto kondisi) |
| **Perangkat dev** | Laragon (PHP + MySQL) di Windows |

---

## Fitur Utama

- **Autentikasi JWT + RBAC** — 3 peran: `pemilik`, `pegawai`, `pelanggan`, dengan proteksi route per peran.
- **Siklus pesanan (state machine)** — Diterima → Ditimbang → Dicuci → Disetrika → Siap → Diambil → Lunas → Selesai. Hanya transisi valid yang diizinkan.
- **QR Nota** — tiap order punya barcode/QR untuk pelacakan cepat via pindai.
- **Foto kondisi awal** — wajib diunggah sebelum order bisa ke status *Ditimbang*.
- **Pembayaran atomik** — pembayaran, kas, dan poin diproses dalam satu transaksi database.
- **Poin loyalitas** — 1 poin untuk setiap Rp10.000 belanja.
- **Dashboard pemilik** — omzet, order aktif, saldo kas, order mendekati batas ambil.
- **Kelola layanan & harga** — perubahan harga tercatat riwayatnya (price snapshot di order).
- **Cashflow** — kas masuk/keluar/pengeluaran.
- **Audit log** — jejak perubahan data penting.
- **Notifikasi** — misalnya saat cucian siap diambil atau sudah selesai.

---

## Struktur Repo

```
.
├── backend/            # Laravel REST API
│   ├── app/
│   │   ├── Http/Controllers/   # Endpoint API
│   │   ├── Models/             # Eloquent models
│   │   ├── Services/           # OrderService, PaymentService, JwtService, dll
│   │   └── Enums/              # OrderStatus, RoleType
│   ├── routes/api.php          # Definisi endpoint /api/v1
│   ├── database/migrations/    # Skema database
│   └── database/seeders/       # Data demo
├── mobile/             # Aplikasi Flutter
│   └── lib/
│       ├── core/               # api_client, theme, constants, widgets
│       └── features/           # auth, orders, scan, dashboard, customer
├── scripts/
│   └── demo_scenario.ps1       # Skenario uji end-to-end (PowerShell)
├── PRD.md              # Product Requirements Document
└── GEMINI.md          # Aturan/inkonvarian teknis proyek
```

---

## Prasyarat

Pastikan terpasang:

- **PHP 8.2+** (disertai Composer)
- **MySQL 8** (Laragon praktis di Windows)
- **Flutter SDK 3.x** + Android SDK (untuk build APK)
- **Git**

Verifikasi cepat:
```bash
php --version
composer --version
flutter --version
```

---

## Cara Menjalankan Backend

```bash
cd backend

# 1. Install dependensi PHP
composer install

# 2. Siapkan konfigurasi environment
cp .env.example .env
php artisan key:generate
#   lalu edit .env: isi JWT_SECRET (lihat catatan di file) dan kredensial DB

# 3. Buat database 'laundryku' di MySQL, lalu migrasi + isi data demo
php artisan migrate --seed

# 4. Jalankan server API (bisa diakses dari HP via --host=0.0.0.0)
php artisan serve --host=0.0.0.0 --port=8000
```

API aktif di `http://127.0.0.1:8000/api/v1`.

> **Catatan MySQL (Laragon):** nyalakan MySQL lewat panel Laragon, atau manual:
> `mysqld --datadir=<path-data-mysql>`. Pastikan service hidup sebelum migrasi.

---

## Cara Menjalankan Aplikasi Flutter

```bash
cd mobile

# 1. Install dependensi Dart
flutter pub get

# 2. Jalankan (pilih device)
flutter devices            # lihat device tersedia
flutter run -d chrome      # web (paling cepat untuk demo)
#  atau
flutter run                # emulator/HP (butuh base URL benar, lihat di bawah)
```

Login dengan salah satu [akun demo](#akun-demo).

---

## Membangun APK

```bash
cd mobile

# Tentukan base URL API ke IP laptop di LAN (ganti sesuai IP Anda)
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.11:8000/api/v1
```

Hasil: `mobile/build/app/outputs/flutter-apk/app-release.apk`

Pasang ke HP:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
atau salin file APK ke HP lalu buka dari File Manager (izinkan "sumber tidak dikenal").

---

## Konfigurasi Base URL API

Base URL diatur di `mobile/lib/core/constants/api_constants.dart` dan dapat di-override saat build via `--dart-define=API_BASE_URL=...`.

| Skenario | Nilai base URL |
|---|---|
| Web (Chrome di mesin yang sama) | `http://127.0.0.1:8000/api/v1` (default) |
| Emulator Android | `http://10.0.2.2:8000/api/v1` (default) |
| **HP fisik (1 WiFi dengan laptop)** | `http://<IP-LAPTOP>:8000/api/v1` via `--dart-define` |

Cari IP laptop (Windows): `ipconfig` → lihat adapter WiFi (mis. `192.168.1.11`).

Pastikan juga:
- API dijalankan dengan `--host=0.0.0.0`
- **Firewall Windows** mengizinkan port 8000 (inbound). Contoh (PowerShell as Admin):
  ```powershell
  New-NetFirewallRule -DisplayName "LaundryKu API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
  ```
- HP & laptop berada di jaringan WiFi yang sama.

---

## Akun Demo

Password untuk semua akun: **`password`**

| Peran | Email | Akses |
|---|---|---|
| Pemilik | `owner@laundryku.com` | Dashboard, kelola harga, cashflow, audit log, otorisasi diskon >10% |
| Pegawai | `kasir1@laundryku.com` | Buat order, transisi status, pembayaran, pindai QR |
| Pelanggan | `budi@gmail.com` | Lihat pesanan, notifikasi, poin |

---

## Pengujian End-to-End

Backend (unit + feature):
```bash
cd backend
php artisan test
```

Skenario demo penuh (butuh API berjalan) — menguji login, pembuatan order, idempotency, validasi diskon, gerbang foto, transisi status, notifikasi, RBAC, pembayaran & poin, dashboard, cashflow:
```powershell
pwsh -File scripts/demo_scenario.ps1
```
Output akhir yang diharapkan: `DEMO SCENARIO COMPLETE`.

---

## Aturan Bisnis Penting

Inkonvarian yang ditegakkan backend (lihat `GEMINI.md` untuk detail):

- **Snapshot harga** — harga layanan dikunci saat order dibuat; perubahan tarif berikutnya tidak mengubah order lama.
- **State machine tunggal** — transisi status hanya lewat satu method; transisi invalid ditolak (HTTP 422).
- **Gerbang foto** — status tidak bisa ke *Ditimbang* sebelum foto kondisi awal diunggah.
- **Pembayaran atomik** — pembayaran + kas + poin dalam satu transaksi DB.
- **Rupiah integer** — semua nominal disimpan sebagai bilangan bulat (Rupiah, bukan sen).
- **Diskon > 10%** — hanya boleh diotorisasi pemilik.
- **Idempotency-Key** — header pada `POST /orders` & `/payments` mencegah duplikasi.
- **Append-only** — tabel audit log & status log tidak boleh diubah/dihapus.

---

## Troubleshooting

| Gejala | Penyebab umum | Solusi |
|---|---|---|
| Login error 500 | MySQL mati | Nyalakan MySQL (Laragon), cek `php artisan migrate` jalan |
| `Table ... cache doesn't exist` | Tabel framework belum dibuat | `php artisan migrate` (Laravel 11 tak auto-create tabel cache/sessions/jobs) |
| Flutter "connection refused" (HP) | Base URL salah / API localhost-only | Gunakan `--dart-define` ke IP LAN + `serve --host=0.0.0.0` + buka firewall |
| APK tidak muncul di HP | Belum terpasang | `adb install -r ...` atau buka APK dari File Manager |
| `INSTALL_FAILED_USER_RESTRICTED` (POCO/HyperOS) | Install via USB dikunci | Aktifkan "Install via USB" di Opsi Developer, atau install dari File Manager |

---

## Lisensi

Proyek akademik — digunakan untuk keperluan pembelajaran.

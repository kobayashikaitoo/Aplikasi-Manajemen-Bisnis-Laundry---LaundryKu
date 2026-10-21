# LaundryKu

Aplikasi sistem informasi dan kasir laundry (kiloan & satuan) berbasis **Flutter** untuk mobile dan **Laravel** untuk backend REST API.

Dibuat untuk tugas mata kuliah Pemrograman Mobile (Semester 5).

---

## Fitur Aplikasi

- **Login 3 Role**:
  - **Pemilik**: Akses dashboard omzet, kelola tarif layanan, buat & atur akun kasir, cek arus kas, dan pantau log aktivitas.
  - **Pegawai (Kasir)**: Input pesanan cucian, upload foto kondisi awal pakaian, update status proses cuci, proses pembayaran kasir, dan scan barcode/QR nota.
  - **Pelanggan**: Cek status pesanan secara real-time, lihat nota digital/QR, pantau & tukar poin reward, serta atur alamat penjemputan.
- **Alur Status Cucian**:
  - Diterima → Ditimbang → Dicuci → Disetrika → Siap Diambil → Selesai.
  - *Catatan:* Cucian wajib difoto terlebih dahulu sebelum masuk proses timbang untuk bukti kondisi pakaian awal pelanggan.
- **Pendaftaran & Pengaturan Akun**:
  - **Pelanggan**: Bisa daftar akun mandiri lewat halaman login (lengkap dengan validasi password dan konfirmasi persetujuan data).
  - **Pegawai/Kasir**: Didaftarkan langsung oleh Pemilik melalui menu "Kelola Pegawai" di Dashboard Pemilik.
  - **Lupa Password**: Bisa reset password mandiri dengan memasukkan email dan nomor HP yang sesuai.
  - **Profil**: Pelanggan bisa atur alamat default & hapus akun; Pegawai bisa cek cabang tugas & ringkasan SOP kerja.
- **Sistem Poin Member**:
  - Otomatis dapat 1 poin setiap kelipatan transaksi Rp10.000. Poin bisa ditukar potongan harga.
- **Scan & Tampil QR Nota**:
  - Setiap pesanan memiliki kode QR/barcode unik agar kasir mudah mencari data order saat cucian diambil.

---

## Tech Stack

- **Mobile App**: Flutter (Dart), State Management Riverpod, Dio (HTTP Client), Mobile Scanner, QR Flutter.
- **Backend API**: Laravel 11, PHP 8.2+, MySQL, JWT Authentication.
- **Environment Dev**: Laragon (Windows), Android Studio Virtual Device / HP Fisik.

---

## Cara Menjalankan Project

### 1. Menjalankan Backend (Laravel)

Pastikan Apache/MySQL di Laragon sudah menyala, lalu buka terminal:

```bash
cd backend

# Install dependency PHP
composer install

# Buat file konfigurasi .env
cp .env.example .env
php artisan key:generate

# Buat database 'laundryku' di MySQL (lewat HeidiSQL / phpMyAdmin)
# lalu jalankan migrasi dan data awal (seeder)
php artisan migrate --seed

# Jalankan server API
php artisan serve --host=0.0.0.0 --port=8000
```

> **Catatan:** Flag `--host=0.0.0.0` wajib dipakai agar backend bisa diakses dari emulator maupun HP fisik di jaringan Wi-Fi yang sama.

### 2. Menjalankan Mobile App (Flutter)

Buka terminal baru:

```bash
cd mobile

# Ambil dependency Dart
flutter pub get

# Jalankan ke device / emulator
flutter run
```

---

## Akun untuk Uji Coba (Demo)

Semua akun dummy default menggunakan password: **`password`**

| Role | Email | Password | Keterangan |
|---|---|---|---|
| **Pemilik** | `owner@laundryku.com` | `password` | Login pemilik toko (akses full dashboard & kelola staf) |
| **Kasir 1** | `kasir1@laundryku.com` | `password` | Akun kasir cabang utama |
| **Kasir 2** | `kasir2@laundryku.com` | `password` | Akun kasir cabang kedua |
| **Pelanggan** | `budi@gmail.com` | `password` | Akun contoh pelanggan aktif |
| **Pelanggan** | `siti@gmail.com` | `password` | Akun contoh pelanggan aktif |

> **Catatan Pembuatan Akun Baru:**
> - Jika ingin mencoba membuat akun **Pelanggan baru**, klik tombol **Daftar Akun Pelanggan** di halaman login.
> - Jika ingin membuat akun **Kasir baru**, login dulu sebagai Pemilik (`owner@laundryku.com`), buka tab Dashboard, lalu pilih menu **Kelola Pegawai** untuk menambah akun kasir baru.

---

## Pengaturan Koneksi API (Base URL)

Pengaturan alamat backend ada di `mobile/lib/core/constants/api_constants.dart`:

- **Emulator Android Studio**: Otomatis mengarah ke `http://10.0.2.2:8000/api/v1` (gateway host laptop).
- **Browser (Chrome)**: Mengarah ke `http://127.0.0.1:8000/api/v1`.
- **HP Fisik (via Wi-Fi)**:
  Jalankan aplikasi dengan menyertakan IP laptop Anda:
  ```bash
  flutter run --dart-define=API_BASE_URL=http://<IP_LAPTOP_ANDA>:8000/api/v1
  ```
  *(Cari IP laptop lewat perintah `ipconfig` di CMD/PowerShell, lihat bagian IPv4 Wi-Fi).*

---

## Struktur Folder

```text
.
├── backend/            # REST API Laravel
│   ├── app/            # Controller, Model, Services (logika bisnis)
│   ├── database/       # Migration skema tabel & Seeder data demo
│   └── routes/api.php  # Definisi endpoint API
├── mobile/             # Aplikasi Flutter
│   └── lib/
│       ├── core/       # Api client, tema warna, konstanta global
│       └── features/   # Modul fitur (auth, order, dashboard, scan QR, dll)
└── scripts/            # Script helper pengujian
```

---

## Troubleshooting Singkat

- **Gagal koneksi dari HP / Emulator (Connection Refused)**:
  - Pastikan backend jalan dengan `--host=0.0.0.0`.
  - Pastikan Windows Firewall mengizinkan port 8000.
  - Jika pakai HP fisik, pastikan HP dan laptop tersambung di satu Wi-Fi yang sama.
- **Error Login 500 saat pertama jalan**:
  - Pastikan service MySQL di Laragon aktif dan perintah `php artisan migrate --seed` sudah berhasil dijalankan.

<?php

namespace Database\Seeders;

use App\Enums\OrderStatus;
use App\Models\AuditLog;
use App\Models\Branch;
use App\Models\BranchSetting;
use App\Models\CashTransaction;
use App\Models\Claim;
use App\Models\Customer;
use App\Models\Delivery;
use App\Models\LoyaltyTransaction;
use App\Models\Notification;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderPhoto;
use App\Models\OrderStatusLog;
use App\Models\Payment;
use App\Models\Role;
use App\Models\Service;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Roles
        $rolePemilik = Role::firstOrCreate(['name' => 'pemilik'], ['guard_name' => 'api']);
        $rolePegawai = Role::firstOrCreate(['name' => 'pegawai'], ['guard_name' => 'api']);
        $rolePelanggan = Role::firstOrCreate(['name' => 'pelanggan'], ['guard_name' => 'api']);
        $roleKurir = Role::firstOrCreate(['name' => 'kurir'], ['guard_name' => 'api']);

        // 2. Branch & Settings
        $branch = Branch::firstOrCreate(
            ['code' => 'LDRY-01'],
            [
                'name' => 'LaundryKu Cabang Utama',
                'address' => 'Jl. Pendidikan No. 45, Denpasar, Bali',
                'phone' => '081234567890',
                'is_active' => true,
            ]
        );

        BranchSetting::firstOrCreate(
            ['branch_id' => $branch->id],
            [
                'holding_period_days' => 7,
                'reminder_lead_days' => 2,
                'points_per_amount' => 1,
                'amount_per_point' => 10000,
            ]
        );

        // 3. Users (Pemilik, 2 Pegawai, 3 Pelanggan)
        $passwordHash = Hash::make('password');

        $owner = User::firstOrCreate(
            ['email' => 'owner@laundryku.com'],
            [
                'role_id' => $rolePemilik->id,
                'branch_id' => $branch->id,
                'name' => 'Pak Hendra (Pemilik)',
                'phone' => '081111111111',
                'password' => $passwordHash,
                'is_active' => true,
            ]
        );

        $staff1 = User::firstOrCreate(
            ['email' => 'kasir1@laundryku.com'],
            [
                'role_id' => $rolePegawai->id,
                'branch_id' => $branch->id,
                'name' => 'Rina (Kasir 1)',
                'phone' => '082222222221',
                'password' => $passwordHash,
                'is_active' => true,
            ]
        );

        $staff2 = User::firstOrCreate(
            ['email' => 'kasir2@laundryku.com'],
            [
                'role_id' => $rolePegawai->id,
                'branch_id' => $branch->id,
                'name' => 'Dodi (Kasir 2)',
                'phone' => '082222222222',
                'password' => $passwordHash,
                'is_active' => true,
            ]
        );

        $kurir1 = User::firstOrCreate(
            ['email' => 'kurir@laundryku.com'],
            [
                'role_id' => $roleKurir->id,
                'branch_id' => $branch->id,
                'name' => 'Bambang (Kurir)',
                'phone' => '083333333331',
                'password' => $passwordHash,
                'is_active' => true,
            ]
        );

        $userBudi = User::firstOrCreate(
            ['email' => 'budi@gmail.com'],
            [
                'role_id' => $rolePelanggan->id,
                'branch_id' => $branch->id,
                'name' => 'Budi Santoso',
                'phone' => '085555555551',
                'password' => $passwordHash,
                'is_active' => true,
            ]
        );

        $userSiti = User::firstOrCreate(
            ['email' => 'siti@gmail.com'],
            [
                'role_id' => $rolePelanggan->id,
                'branch_id' => $branch->id,
                'name' => 'Siti Rahma',
                'phone' => '085555555552',
                'password' => $passwordHash,
                'is_active' => true,
            ]
        );

        $userAgus = User::firstOrCreate(
            ['email' => 'agus@gmail.com'],
            [
                'role_id' => $rolePelanggan->id,
                'branch_id' => $branch->id,
                'name' => 'Agus Pratama',
                'phone' => '085555555553',
                'password' => $passwordHash,
                'is_active' => true,
            ]
        );

        // 4. Customers
        $custBudi = Customer::firstOrCreate(
            ['code' => 'CUST-001'],
            [
                'user_id' => $userBudi->id,
                'branch_id' => $branch->id,
                'name' => 'Budi Santoso',
                'phone' => '085555555551',
                'address' => 'Jl. Melati No. 12, Denpasar',
                'point_balance' => 25,
            ]
        );

        $custSiti = Customer::firstOrCreate(
            ['code' => 'CUST-002'],
            [
                'user_id' => $userSiti->id,
                'branch_id' => $branch->id,
                'name' => 'Siti Rahma',
                'phone' => '085555555552',
                'address' => 'Jl. Mawar No. 8, Denpasar',
                'point_balance' => 10,
            ]
        );

        $custAgus = Customer::firstOrCreate(
            ['code' => 'CUST-003'],
            [
                'user_id' => $userAgus->id,
                'branch_id' => $branch->id,
                'name' => 'Agus Pratama',
                'phone' => '085555555553',
                'address' => 'Jl. Kenanga No. 5, Denpasar',
                'point_balance' => 5,
            ]
        );

        // 5. Services (6 layanan sesuai PRD)
        $services = [
            [
                'name' => 'Kiloan Reguler',
                'unit' => 'kg',
                'price' => 7000,
                'estimate_duration_hours' => 48,
                'min_order' => 1.0,
            ],
            [
                'name' => 'Kiloan Express',
                'unit' => 'kg',
                'price' => 12000,
                'estimate_duration_hours' => 24,
                'min_order' => 1.0,
            ],
            [
                'name' => 'Satuan Kemeja',
                'unit' => 'pcs',
                'price' => 10000,
                'estimate_duration_hours' => 24,
                'min_order' => 1.0,
            ],
            [
                'name' => 'Sepatu',
                'unit' => 'pasang',
                'price' => 25000,
                'estimate_duration_hours' => 72,
                'min_order' => 1.0,
            ],
            [
                'name' => 'Karpet per m2',
                'unit' => 'm2',
                'price' => 15000,
                'estimate_duration_hours' => 72,
                'min_order' => 1.0,
            ],
            [
                'name' => 'Bed Cover',
                'unit' => 'pcs',
                'price' => 30000,
                'estimate_duration_hours' => 48,
                'min_order' => 1.0,
            ],
        ];

        $serviceModels = [];
        foreach ($services as $svc) {
            $serviceModels[$svc['name']] = Service::firstOrCreate(
                ['branch_id' => $branch->id, 'name' => $svc['name']],
                $svc
            );
        }

        // 6. 18 Demo Orders dengan Status Beragam
        $customersList = [$custBudi, $custSiti, $custAgus];
        $statuses = [
            OrderStatus::Diterima->value,
            OrderStatus::Ditimbang->value,
            OrderStatus::Dicuci->value,
            OrderStatus::Disetrika->value,
            OrderStatus::Siap->value,
            OrderStatus::Siap->value, // One near due
            OrderStatus::Diambil->value,
            OrderStatus::Lunas->value,
            OrderStatus::Selesai->value,
            OrderStatus::Selesai->value,
            OrderStatus::Selesai->value,
            OrderStatus::TidakDiambil->value,
            OrderStatus::Dibatalkan->value,
            OrderStatus::Diterima->value,
            OrderStatus::Ditimbang->value,
            OrderStatus::Dicuci->value,
            OrderStatus::Selesai->value,
            OrderStatus::Selesai->value,
        ];

        $todayStr = Carbon::now('UTC')->format('Ymd');

        foreach ($statuses as $index => $statusName) {
            $num = $index + 1;
            $orderNo = "LDRY-{$todayStr}-" . str_pad((string) $num, 4, '0', STR_PAD_LEFT);
            $cust = $customersList[$index % count($customersList)];
            $createdAt = Carbon::now('UTC')->subDays(rand(0, 5))->subHours(rand(1, 12));

            // Demo order 6 is specifically near due (< 2 days)
            $completedAt = in_array($statusName, ['Siap', 'Diambil', 'Lunas', 'Selesai', 'Tidak Diambil'])
                ? $createdAt->copy()->addHours(24)
                : null;

            $dueAt = null;
            if ($completedAt) {
                if ($statusName === 'Tidak Diambil') {
                    $dueAt = $createdAt->copy()->subHours(2); // Already expired
                } elseif ($index === 5) {
                    $dueAt = Carbon::now('UTC')->addHours(20); // Near due (< 2 days)
                } else {
                    $dueAt = $completedAt->copy()->addDays(7);
                }
            }

            $order = Order::firstOrCreate(
                ['order_no' => $orderNo],
                [
                    'branch_id' => $branch->id,
                    'customer_id' => $cust->id,
                    'created_by_user_id' => $staff1->id,
                    'barcode' => $orderNo,
                    'status' => $statusName,
                    'subtotal' => 45000,
                    'discount_amount' => 0,
                    'total_amount' => 45000,
                    'holding_period_days' => 7,
                    'due_at' => $dueAt,
                    'completed_at' => $completedAt,
                    'pickup_at' => in_array($statusName, ['Diambil', 'Lunas', 'Selesai']) ? $completedAt?->copy()->addHours(6) : null,
                    'notes' => "Order demo ke-{$num}",
                    'created_at' => $createdAt,
                    'updated_at' => $createdAt,
                ]
            );

            // Add Items
            if ($order->items()->count() === 0) {
                $order->items()->create([
                    'service_id' => $serviceModels['Kiloan Reguler']->id,
                    'service_name_snap' => 'Kiloan Reguler',
                    'unit_snap' => 'kg',
                    'unit_price' => 7000,
                    'quantity' => 3.0,
                    'subtotal' => 21000,
                ]);

                $order->items()->create([
                    'service_id' => $serviceModels['Sepatu']->id,
                    'service_name_snap' => 'Sepatu',
                    'unit_snap' => 'pasang',
                    'unit_price' => 25000,
                    'quantity' => 1.0,
                    'subtotal' => 25000,
                ]);

                $order->subtotal = 46000;
                $order->total_amount = 46000;
                $order->save();
            }

            // Add Initial Photo for orders past Diterima
            if ($statusName !== OrderStatus::Diterima->value && $order->photos()->count() === 0) {
                OrderPhoto::create([
                    'order_id' => $order->id,
                    'photo_path' => 'https://images.unsplash.com/photo-1545173168-9f1947eebb7f?auto=format&fit=crop&w=400&q=80',
                    'photo_type' => 'initial',
                    'uploaded_by_user_id' => $staff1->id,
                    'created_at' => $createdAt,
                ]);
            }

            // Add Status Logs
            if ($order->statusLogs()->count() === 0) {
                OrderStatusLog::create([
                    'order_id' => $order->id,
                    'from_status' => null,
                    'to_status' => OrderStatus::Diterima->value,
                    'changed_by_user_id' => $staff1->id,
                    'reason' => 'Order baru dibuat',
                    'created_at' => $createdAt,
                ]);

                if ($statusName !== OrderStatus::Diterima->value) {
                    OrderStatusLog::create([
                        'order_id' => $order->id,
                        'from_status' => OrderStatus::Diterima->value,
                        'to_status' => $statusName,
                        'changed_by_user_id' => $staff1->id,
                        'reason' => 'Diproses oleh kasir',
                        'created_at' => $createdAt->copy()->addMinutes(30),
                    ]);
                }
            }

            // Payments & Cash Transactions for Lunas and Selesai orders
            if (in_array($statusName, ['Lunas', 'Selesai']) && $order->payments()->count() === 0) {
                $pay = Payment::create([
                    'order_id' => $order->id,
                    'received_by_user_id' => $staff1->id,
                    'payment_method' => 'cash',
                    'amount' => $order->total_amount,
                    'reference_no' => 'CASH-' . $order->order_no,
                    'idempotency_key' => 'seed-pay-' . $order->id,
                    'created_at' => $createdAt->copy()->addHours(30),
                ]);

                CashTransaction::create([
                    'branch_id' => $branch->id,
                    'order_id' => $order->id,
                    'user_id' => $staff1->id,
                    'transaction_type' => 'in',
                    'category' => 'payment',
                    'amount' => $order->total_amount,
                    'description' => "Pembayaran Order #{$order->order_no} via CASH",
                    'created_at' => $createdAt->copy()->addHours(30),
                ]);
            }
        }

        // 7. 5 Pengeluaran Operasional (Cash Out)
        $expenses = [
            ['Deterjen Cair 20 Liter', 180000, 'detergent'],
            ['Pewangi & Pelembut Pakaian', 120000, 'fragrance'],
            ['Plastik Packing Laundry Ukuran Besar', 75000, 'packaging'],
            ['Gas LPG 3kg x 4 tabung', 88000, 'gas'],
            ['Listrik Operasional Mingguan', 250000, 'electricity'],
        ];

        foreach ($expenses as $i => [$desc, $amount, $cat]) {
            CashTransaction::firstOrCreate(
                ['description' => $desc],
                [
                    'branch_id' => $branch->id,
                    'order_id' => null,
                    'user_id' => $owner->id,
                    'transaction_type' => 'out',
                    'category' => 'expense',
                    'amount' => $amount,
                    'created_at' => Carbon::now('UTC')->subDays($i + 1),
                ]
            );
        }

        // 8. Demo Notifications for Budi
        Notification::firstOrCreate(
            ['user_id' => $userBudi->id, 'title' => 'Cucian Selesai!'],
            [
                'order_id' => 1,
                'type' => 'ready',
                'message' => 'Order #' . Order::first()->order_no . ' telah selesai diproses dan siap diambil.',
                'is_read' => false,
                'created_at' => Carbon::now('UTC')->subHours(3),
            ]
        );

        Notification::firstOrCreate(
            ['user_id' => $userBudi->id, 'title' => 'Poin Reward Bertambah'],
            [
                'order_id' => null,
                'type' => 'system',
                'message' => 'Selamat! Anda mendapatkan 4 poin dari transaksi terakhir.',
                'is_read' => true,
                'created_at' => Carbon::now('UTC')->subDays(2),
            ]
        );

        // 9. Deliveries for Kurir
        $firstOrder = Order::first();
        $lastOrder = Order::latest()->first();

        if ($firstOrder) {
            Delivery::firstOrCreate(
                ['order_id' => $firstOrder->id, 'type' => 'delivery'],
                [
                    'courier_user_id' => $kurir1->id,
                    'type' => 'delivery',
                    'status' => 'pending',
                    'scheduled_at' => Carbon::now('UTC')->addHours(2),
                    'completed_at' => null,
                    'fee' => 10000,
                ]
            );
        }

        if ($lastOrder && $lastOrder->id !== $firstOrder?->id) {
            Delivery::firstOrCreate(
                ['order_id' => $lastOrder->id, 'type' => 'pickup'],
                [
                    'courier_user_id' => $kurir1->id,
                    'type' => 'pickup',
                    'status' => 'on_the_way',
                    'scheduled_at' => Carbon::now('UTC')->subHours(1),
                    'completed_at' => null,
                    'fee' => 8000,
                ]
            );
        }

        // 10. Sample Claim for Owner approval
        if ($firstOrder && $custBudi) {
            Claim::firstOrCreate(
                ['order_id' => $firstOrder->id],
                [
                    'customer_id' => $custBudi->id,
                    'claim_type' => 'Pakaian Rusak / Robek',
                    'description' => 'Ada robekan kecil di bagian kancing kemeja putih saat diterima kembali.',
                    'status' => 'Diajukan',
                    'resolution' => null,
                    'refund_amount' => 35000,
                ]
            );
        }
    }
}

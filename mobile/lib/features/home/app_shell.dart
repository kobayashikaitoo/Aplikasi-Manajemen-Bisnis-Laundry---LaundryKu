import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/account_screen.dart';
import '../auth/auth_controller.dart';
import '../courier/courier_home_screen.dart';
import '../customer/notifications_screen.dart';
import '../customer/points_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../orders/create_order_screen.dart';
import '../orders/order_detail_screen.dart';
import '../orders/order_list_screen.dart';
import '../orders/orders_providers.dart';
import '../scan/scan_screen.dart';

/// Root navigation shell; tab set depends on the logged-in role.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final isCustomer = user.isCustomer;

    final List<Widget> pages;
    final List<NavigationDestination> nav;

    if (isCustomer) {
      pages = [
        _CustomerHomeTab(
          onNavigateToOrders: () => setState(() => _index = 1),
          onNavigateToPoints: () => setState(() => _index = 2),
        ),
        const OrderListScreen(),
        const PointsScreen(),
        const AccountScreen(),
      ];
      nav = const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Pesanan',
        ),
        NavigationDestination(
          icon: Icon(Icons.star_outline_rounded),
          selectedIcon: Icon(Icons.star_rounded),
          label: 'Poin',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Akun',
        ),
      ];
    } else if (user.isCourier) {
      pages = const [
        CourierHomeScreen(),
        ScanScreen(),
        AccountScreen(),
      ];
      nav = const [
        NavigationDestination(
          icon: Icon(Icons.two_wheeler_outlined),
          selectedIcon: Icon(Icons.two_wheeler_rounded),
          label: 'Tugas',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Pindai',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Akun',
        ),
      ];
    } else {
      final isOwner = user.isOwner;
      pages = [
        if (isOwner) const DashboardScreen(),
        const OrderListScreen(),
        const ScanScreen(),
        const CreateOrderScreen(),
        const AccountScreen(),
      ];
      nav = [
        if (isOwner)
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Order',
        ),
        const NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Pindai',
        ),
        const NavigationDestination(
          icon: Icon(Icons.add_circle_outline_rounded),
          selectedIcon: Icon(Icons.add_circle_rounded),
          label: 'Buat',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Akun',
        ),
      ];
    }

    final safeIndex = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AppColors.primaryLight,
        destinations: nav,
      ),
    );
  }
}

/// Customer Home Tab (Mirrors Page 2 of the wireframe/mockup)
class _CustomerHomeTab extends ConsumerWidget {
  final VoidCallback onNavigateToOrders;
  final VoidCallback onNavigateToPoints;

  const _CustomerHomeTab({
    required this.onNavigateToOrders,
    required this.onNavigateToPoints,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi,';
    if (hour < 15) return 'Selamat siang,';
    if (hour < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final name = user?.name ?? 'Pelanggan';
    final customerId = user?.customerId;
    final ordersAsync = ref.watch(ordersListProvider);
    final pointsAsync =
        customerId != null ? ref.watch(pointsProvider(customerId)) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ordersListProvider);
            if (customerId != null) {
              ref.invalidate(pointsProvider(customerId));
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Greeting + Notification Bell
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Tombol Utama "+ Pesan Laundry" (Mockup Hal 2)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateOrderScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Pesan Laundry',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Grid Layanan (Kiloan, Satuan, Express, Sepatu, Karpet)
                Text(
                  'Layanan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _serviceCategory(
                      icon: Icons.scale_outlined,
                      label: 'Kiloan',
                      onTap: () => _openCreateOrderWith(context, 'Kiloan'),
                    ),
                    _serviceCategory(
                      icon: Icons.checkroom_outlined,
                      label: 'Satuan',
                      onTap: () => _openCreateOrderWith(context, 'Satuan'),
                    ),
                    _serviceCategory(
                      icon: Icons.bolt_rounded,
                      label: 'Express',
                      onTap: () => _openCreateOrderWith(context, 'Kiloan'),
                    ),
                    _serviceCategory(
                      icon: Icons.dry_cleaning_rounded,
                      label: 'Sepatu',
                      onTap: () => _openCreateOrderWith(context, 'Sepatu'),
                    ),
                    _serviceCategory(
                      icon: Icons.grid_view_rounded,
                      label: 'Karpet',
                      onTap: () => _openCreateOrderWith(context, 'Karpet'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Kartu Poin Member (Mockup Hal 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Poin member',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF9A3412),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          pointsAsync?.when(
                                data: (pts) => Text(
                                  '${pts.pointBalance} poin',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF7C2D12),
                                  ),
                                ),
                                loading: () => const Text('Memuat poin...'),
                                error: (err, stack) => const Text('0 poin'),
                              ) ??
                              Text(
                                '0 poin',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF7C2D12),
                                ),
                              ),
                        ],
                      ),
                      InkWell(
                        onTap: onNavigateToPoints,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                'Tukar poin',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Riwayat Terakhir
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Riwayat terakhir',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    InkWell(
                      onTap: onNavigateToOrders,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Semua',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // List order ringkas
                ordersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Gagal memuat riwayat: $e'),
                  ),
                  data: (orders) {
                    if (orders.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 36,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Belum ada pesanan cucian.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Tampilkan maksimal 3 order terbaru di beranda
                    final recentOrders = orders.take(3).toList();

                    return Column(
                      children: recentOrders.map((order) {
                        final itemsSummary = order.items.isNotEmpty
                            ? order.items
                                .map((it) => '${it.serviceNameSnap} · ${it.quantityLabel}')
                                .join(', ')
                            : 'Order Laundry';
                        final dateStr = Formatters.dateWita(order.createdAt);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(orderId: order.id),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemsSummary,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${order.orderNo} · $dateStr',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  StatusChip(status: order.status, dense: true),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCreateOrderWith(BuildContext context, [String? category]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateOrderScreen(initialCategory: category)),
    );
  }

  Widget _serviceCategory({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

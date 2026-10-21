import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_providers.dart';
import 'audit_log_screen.dart';
import 'cashflow_screen.dart';
import 'services_screen.dart';
import 'staff_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const LoadingView(message: 'Memuat ringkasan hari ini...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (dash) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  Formatters.dateWita(DateTime.now().toUtc()),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: StatTile(
                            label: 'Omzet hari ini',
                            value: Formatters.rupiah(dash.omzetToday),
                            icon: Icons.trending_up_rounded,
                            color: AppColors.success)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: StatTile(
                            label: 'Order baru',
                            value: '${dash.orderCountToday}',
                            icon: Icons.receipt_long_rounded,
                            color: AppColors.info)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: StatTile(
                            label: 'Order aktif',
                            value: '${dash.activeOrdersCount}',
                            icon: Icons.running_with_errors_rounded,
                            color: AppColors.warning)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: StatTile(
                            label: 'Saldo kas',
                            value: Formatters.rupiah(dash.currentBalance),
                            icon: Icons.account_balance_wallet_rounded,
                            color: AppColors.primary)),
                  ],
                ),
              ),
              const SectionHeader(title: 'Kas hari ini'),
              SectionCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _cashItem('Masuk', dash.cashInToday, AppColors.success,
                        Icons.arrow_downward_rounded),
                    _cashItem('Keluar', dash.cashOutToday, AppColors.danger,
                        Icons.arrow_upward_rounded),
                    _cashItem('Bersih', dash.cashInToday - dash.cashOutToday,
                        AppColors.primary, Icons.calculate_rounded),
                  ],
                ),
              ),
              const SectionHeader(title: 'Order per status'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in dash.statusCounts.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusChip(status: entry.key, dense: true),
                            const SizedBox(width: 6),
                            Text('${entry.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SectionHeader(title: '⚠ Siap mendekati batas ambil'),
              if (dash.nearDueOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Tidak ada order yang mendekati batas.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ...dash.nearDueOrders.map((o) => SectionCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: o.id))),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_rounded,
                            color: AppColors.danger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.orderNo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text(
                                  '${o.customer?.name ?? ''} · batas ${Formatters.dateWita(o.dueAt)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const StatusChip(status: 'Siap', dense: true),
                      ],
                    ),
                  )),
              const SectionHeader(title: 'Menu pemilik'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _menuTile(context, Icons.people_rounded, 'Kelola Pegawai / Kasir',
                        'Daftar dan buat akun kasir baru', () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const StaffScreen()));
                    }),
                    _menuTile(context, Icons.sell_rounded, 'Layanan & Harga',
                        'Ubah tarif, tercatat di riwayat', () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ServicesScreen()));
                    }),
                    _menuTile(context, Icons.swap_vert_rounded, 'Cashflow',
                        'Kas masuk, keluar, dan pengeluaran', () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CashflowScreen()));
                    }),
                    _menuTile(context, Icons.fact_check_rounded, 'Audit Log',
                        'Jejak perubahan sistem', () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AuditLogScreen()));
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cashItem(String label, int amount, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(Formatters.rupiah(amount),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _menuTile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

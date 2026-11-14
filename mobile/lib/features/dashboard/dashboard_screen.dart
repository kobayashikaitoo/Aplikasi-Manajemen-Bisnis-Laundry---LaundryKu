import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/data/models.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_providers.dart';
import 'approval_screen.dart';
import 'approvals_provider.dart';
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
              Builder(builder: (context) {
                final approvals = ref.watch(approvalsProvider);
                if (approvals.pendingCount <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded,
                            color: AppColors.warning, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${approvals.pendingCount} Permintaan Butuh Persetujuan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.warning,
                                ),
                              ),
                              const Text(
                                'Klaim pelanggan, diskon khusus, atau batal order.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ApprovalScreen()));
                          },
                          child: const Text('Tinjau'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
              const SectionHeader(title: '📈 Tren omzet 7 hari terakhir'),
              _buildWeeklyOmzetChart(context, dash.dailyOmzet7d),
              const SectionHeader(title: '📊 Distribusi pendapatan per layanan'),
              _buildRevenuePerServiceSection(context, dash.revenuePerService),
              const SectionHeader(title: '👥 Pelanggan tidak aktif (>30 hari)'),
              _buildInactiveCustomersSection(context, dash.inactiveCustomers),
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
                    _menuTile(context, Icons.verified_user_rounded, 'Persetujuan & Otorisasi',
                        'Otorisasi diskon, pembatalan & klaim', () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ApprovalScreen()));
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

  Widget _buildWeeklyOmzetChart(BuildContext context, List<DailyOmzetModel> dailyOmzet) {
    if (dailyOmzet.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('Belum ada data tren omzet 7 hari.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
    }

    final maxOmzet = dailyOmzet.fold<int>(0, (max, item) => item.omzet > max ? item.omzet : max);
    final total7d = dailyOmzet.fold<int>(0, (sum, item) => sum + item.omzet);
    final avgDaily = total7d > 0 ? (total7d / dailyOmzet.length).round() : 0;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total 7 Hari Terakhir',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.rupiah(total7d),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Rata-rata: ${Formatters.rupiah(avgDaily)}/hr',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: dailyOmzet.map((item) {
                  final parsedDate = DateTime.tryParse(item.date) ?? DateTime.now();
                  final dayLabel = DateFormat('E', 'id_ID').format(parsedDate);
                  final dateNum = DateFormat('d/M').format(parsedDate);
                  final ratio = maxOmzet > 0 ? (item.omzet / maxOmzet).clamp(0.08, 1.0) : 0.08;
                  final isToday = item.date == todayStr;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item.omzet > 0)
                            Text(
                              item.omzet >= 1000000
                                  ? '${(item.omzet / 1000000).toStringAsFixed(1)}jt'
                                  : item.omzet >= 1000
                                      ? '${(item.omzet / 1000).round()}k'
                                      : '${item.omzet}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isToday ? AppColors.accent : AppColors.textSecondary,
                              ),
                            )
                          else
                            const SizedBox(height: 12),
                          const SizedBox(height: 4),
                          Container(
                            height: 75 * ratio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isToday
                                    ? [AppColors.accent, AppColors.accent.withValues(alpha: 0.75)]
                                    : item.omzet > 0
                                        ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]
                                        : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dayLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                              color: isToday ? AppColors.accent : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            dateNum,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenuePerServiceSection(BuildContext context, List<ServiceRevenueModel> revenues) {
    if (revenues.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('Belum ada data pendapatan per layanan.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
    }

    final totalAll = revenues.fold<int>(0, (sum, r) => sum + r.totalRevenue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: revenues.map((item) {
            final pct = totalAll > 0 ? (item.totalRevenue / totalAll) : 0.0;
            final pctLabel = (pct * 100).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.serviceName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.rupiah(item.totalRevenue),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Volume: ${item.totalQuantity % 1 == 0 ? item.totalQuantity.toInt() : item.totalQuantity.toStringAsFixed(1)} unit/kg',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '$pctLabel% omzet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInactiveCustomersSection(BuildContext context, List<CustomerModel> inactiveList) {
    if (inactiveList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.sentiment_satisfied_alt_rounded, color: AppColors.success, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bagus! Semua pelanggan aktif bertransaksi dalam 30 hari terakhir.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_off_outlined, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${inactiveList.length} Pelanggan Perlu Dihubungi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '> 30 Hari Pasif',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ajak kembali pelanggan lama dengan mengingatkan saldo poin atau memberikan penawaran khusus.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(height: 20),
            ...inactiveList.map((cust) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        cust.name.isNotEmpty ? cust.name[0].toUpperCase() : '?',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cust.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${cust.phone} · ${cust.pointBalance} poin reward',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showWinBackDialog(context, cust),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 13),
                      label: Text(
                        'Ajak Kembali',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showWinBackDialog(BuildContext context, CustomerModel cust) {
    final cleanPhone = cust.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final waPhone = cleanPhone.startsWith('0') ? '62${cleanPhone.substring(1)}' : cleanPhone;
    final message = 'Halo Kak ${cust.name}! 🧺✨\n\n'
        'Kami dari LaundryKu kangen nih mencuci pakaian rapi dan wangi untuk Kakak.\n'
        'Saat ini Kakak masih memiliki saldo ${cust.pointBalance} poin reward yang bisa langsung ditukarkan dengan potongan harga di pesanan berikutnya.\n\n'
        'Dapatkan juga penawaran spesial minggu ini! Pesan antar-jemput mudah lewat aplikasi LaundryKu ya. Terima kasih banyak Kak 🙏';
    final waUrl = 'https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.campaign_rounded, color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ajakan Kembali (Win-Back)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Pesan Promosi untuk ${cust.name} (${cust.phone})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_chat_unread_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Pratinjau Pesan Otomatis (Tanpa Biaya API):',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat_rounded),
              label: Text(
                'Salin Pesan Ajakan (Siap Kirim ke WA)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                Navigator.pop(ctx);
                showSnack(context, 'Pesan ajakan kembali untuk ${cust.name} berhasil disalin!');
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.link_rounded),
              label: Text(
                'Salin Tautan WhatsApp Lengkap (wa.me)',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: waUrl));
                Navigator.pop(ctx);
                showSnack(context, 'Tautan link WhatsApp berhasil disalin ke clipboard.');
              },
            ),
          ],
        ),
      ),
    );
  }
}

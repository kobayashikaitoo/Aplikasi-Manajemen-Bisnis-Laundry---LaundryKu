import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import 'data/models.dart';
import 'sync_queue_provider.dart';

class SyncQueueScreen extends ConsumerStatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  ConsumerState<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends ConsumerState<SyncQueueScreen> {
  int _selectedFilter = 0; // 0: Semua, 1: Menunggu, 2: Tersinkron

  void _showPayloadDetail(SyncQueueItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detail Payload Antrean',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${item.id} · Ref: ${item.orderNo}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(item.payload),
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (item.isPending || item.isFailed)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(syncQueueProvider.notifier).retryItem(item.id);
                    showSnack(context, 'Mencoba sinkronisasi item ${item.orderNo}...');
                  },
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Sinkronkan Item Ini'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncQueueProvider);

    final filteredItems = syncState.items.where((i) {
      if (_selectedFilter == 1) return i.isPending;
      if (_selectedFilter == 2) return i.isSynced;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Antrean Sinkronisasi Kasir',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Simulasi Transaksi Offline',
            icon: const Icon(Icons.add_shopping_cart_rounded),
            onPressed: () async {
              await ref.read(syncQueueProvider.notifier).simulateOfflineOrder();
              if (context.mounted) {
                showSnack(context, 'Pesanan simulasi offline berhasil masuk ke antrean.');
              }
            },
          ),
          IconButton(
            tooltip: 'Cek Koneksi Server',
            icon: const Icon(Icons.wifi_find_rounded),
            onPressed: () =>
                ref.read(syncQueueProvider.notifier).checkConnection(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncQueueProvider.notifier).checkConnection();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Connection Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: syncState.isOnline
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (syncState.isOnline ? Colors.green : Colors.red)
                        .withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: syncState.isOnline
                          ? AppColors.successLight
                          : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      syncState.isOnline
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: syncState.isOnline
                          ? AppColors.success
                          : AppColors.danger,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: syncState.isOnline
                                    ? AppColors.success
                                    : AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              syncState.isOnline
                                  ? 'Online · Terhubung ke Server'
                                  : 'Offline · Server Tidak Terjangkau',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: syncState.isOnline
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          syncState.isOnline
                              ? 'Latensi API: ${syncState.latencyMs} ms · Siap sinkronkan data'
                              : 'Transaksi kasir disimpan lokal dan akan disinkronkan saat online',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(syncQueueProvider.notifier)
                        .checkConnection(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Tes Ping',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Summary KPI Grid
            Row(
              children: [
                Expanded(
                  child: _kpiTile(
                    label: 'Total Antrean',
                    value: '${syncState.items.length}',
                    color: AppColors.textPrimary,
                    bg: const Color(0xFFF1F5F9),
                    icon: Icons.list_alt_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiTile(
                    label: 'Menunggu',
                    value: '${syncState.pendingCount}',
                    color: AppColors.warning,
                    bg: AppColors.warningLight,
                    icon: Icons.hourglass_top_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiTile(
                    label: 'Tersinkron',
                    value: '${syncState.syncedCount}',
                    color: AppColors.success,
                    bg: AppColors.successLight,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Tombol Utama Aksi Sinkronisasi
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: syncState.isSyncing
                        ? null
                        : () async {
                            await ref
                                .read(syncQueueProvider.notifier)
                                .syncAll();
                            if (context.mounted) {
                              showSnack(context,
                                  'Semua antrean transaksi berhasil disinkronkan ke server.');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: syncState.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      syncState.isSyncing
                          ? 'Menyinkronkan...'
                          : 'Sinkronkan Sekarang',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.more_horiz_rounded,
                        color: AppColors.textPrimary),
                  ),
                  onSelected: (val) {
                    if (val == 'simulate') {
                      ref
                          .read(syncQueueProvider.notifier)
                          .simulateOfflineOrder();
                      showSnack(context, 'Ditambahkan transaksi dummy offline.');
                    } else if (val == 'clear_synced') {
                      ref.read(syncQueueProvider.notifier).clearSynced();
                      showSnack(context, 'Riwayat tersinkronisasi dibersihkan.');
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'simulate',
                      child: Row(
                        children: [
                          Icon(Icons.add_shopping_cart_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Simulasi Pesanan Offline'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_synced',
                      child: Row(
                        children: [
                          Icon(Icons.cleaning_services_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Bersihkan Yang Berhasil'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. Filter Segmented Bar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _tabButton('Semua (${syncState.items.length})', 0),
                  ),
                  Expanded(
                    child: _tabButton('Menunggu (${syncState.pendingCount})', 1),
                  ),
                  Expanded(
                    child: _tabButton('Tersinkron (${syncState.syncedCount})', 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Daftar Item Antrean
            if (filteredItems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.done_all_rounded,
                          size: 32,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tidak ada antrean dalam kategori ini',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Semua data transaksi kasir aman dan mutakhir.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredItems.map((item) => _queueCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _kpiTile({
    required String label,
    required String value,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _queueCard(SyncQueueItem item) {
    final IconData actionIcon;
    final Color actionColor;

    switch (item.actionType) {
      case 'CREATE_ORDER':
        actionIcon = Icons.add_shopping_cart_rounded;
        actionColor = const Color(0xFF6366F1); // Indigo
        break;
      case 'PAYMENT':
        actionIcon = Icons.payments_rounded;
        actionColor = AppColors.success;
        break;
      case 'UPDATE_STATUS':
        actionIcon = Icons.published_with_changes_rounded;
        actionColor = const Color(0xFF0284C7); // Sky
        break;
      case 'UPLOAD_PHOTO':
        actionIcon = Icons.photo_camera_rounded;
        actionColor = const Color(0xFF8B5CF6); // Purple
        break;
      default:
        actionIcon = Icons.receipt_long_rounded;
        actionColor = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPayloadDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(actionIcon, color: actionColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No: ${item.orderNo} · ${item.customerName}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(item),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Waktu: ${Formatters.dateWita(item.queuedAt)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (item.amount > 0)
                    Text(
                      Formatters.rupiah(item.amount),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(SyncQueueItem item) {
    if (item.isSynced) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 13, color: AppColors.success),
            const SizedBox(width: 4),
            Text(
              'Tersinkron',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    } else if (item.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 13, color: AppColors.danger),
            const SizedBox(width: 4),
            Text(
              'Gagal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_bottom_rounded,
                size: 13, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              'Menunggu',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import '../orders/data/models.dart';
import '../orders/order_detail_screen.dart';
import '../scan/scan_screen.dart';
import 'deliveries_provider.dart';

class CourierHomeScreen extends ConsumerStatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  ConsumerState<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends ConsumerState<CourierHomeScreen> {
  int _selectedTab = 0; // 0: Semua, 1: Jemput, 2: Antar, 3: Selesai
  bool _isOnlineDuty = true;

  void _showContactDialog(BuildContext context, String name, String phone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        phone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.chat_bubble_rounded),
              label: Text(
                'Salin Nomor WhatsApp ($phone)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                Navigator.pop(ctx);
                showSnack(context, 'Nomor $phone berhasil disalin ke clipboard.');
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Salin Nomor Telepon'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                Navigator.pop(ctx);
                showSnack(context, 'Nomor $phone berhasil disalin ke clipboard.');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteDialog(BuildContext context, String custName, String address, String orderNo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.directions_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rute Pengantaran #$orderNo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Pelanggan: $custName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, size: 20, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Salin Alamat Lengkap'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                Navigator.pop(ctx);
                showSnack(context, 'Alamat pengantaran berhasil disalin ke clipboard.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProofAndCompleteSheet(DeliveryModel delivery, String label) async {
    Uint8List? imageBytes;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.successLight,
                    child: Icon(Icons.camera_alt_rounded, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bukti Serah Terima Foto',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Order #${delivery.order?.orderNo ?? delivery.orderId} · $label',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (imageBytes != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      ),
                      onPressed: () {
                        setSheetState(() {
                          imageBytes = null;
                        });
                      },
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        'Ambil foto bukti serah terima cucian',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unggah foto pakaian yang diterima/diserahkan sebagai bukti serah terima sah (tanpa kode OTP).',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text('Kamera'),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 1280,
                                imageQuality: 70,
                              );
                              if (file != null) {
                                final bytes = await file.readAsBytes();
                                setSheetState(() {
                                  imageBytes = bytes;
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text('Galeri'),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1280,
                                imageQuality: 70,
                              );
                              if (file != null) {
                                final bytes = await file.readAsBytes();
                                setSheetState(() {
                                  imageBytes = bytes;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  isSubmitting ? 'Memproses...' : 'Konfirmasi Selesai & Kirim Bukti',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setSheetState(() => isSubmitting = true);
                        String? base64Photo;
                        if (imageBytes != null) {
                          base64Photo = 'data:image/jpeg;base64,${base64Encode(imageBytes!)}';
                        }
                        final ok = await ref
                            .read(deliveriesProvider.notifier)
                            .updateStatus(delivery.id, 'completed', proofPhoto: base64Photo);
                        if (mounted) {
                          Navigator.pop(ctx);
                          if (ok) {
                            showSnack(context, 'Tugas $label berhasil diselesaikan beserta bukti foto.');
                          } else {
                            showSnack(context, 'Gagal menyelesaikan tugas.', isError: true);
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(DeliveryModel delivery, String newStatus, String label) async {
    if (newStatus == 'completed') {
      await _showProofAndCompleteSheet(delivery, label);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi $label?'),
        content: Text(
          'Perbarui status tugas #${delivery.order?.orderNo ?? delivery.orderId} menjadi "$label"?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Perbarui'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await ref
          .read(deliveriesProvider.notifier)
          .updateStatus(delivery.id, newStatus);
      if (mounted) {
        if (ok) {
          showSnack(context, 'Status tugas berhasil diperbarui ke "$label".');
        } else {
          showSnack(context, 'Gagal memperbarui status tugas.', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final state = ref.watch(deliveriesProvider);

    final filteredItems = state.items.where((i) {
      if (_selectedTab == 1) return i.isPickup && !i.isCompleted;
      if (_selectedTab == 2) return i.isDelivery && !i.isCompleted;
      if (_selectedTab == 3) return i.isCompleted;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tugas Antar-Jemput',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Kurir: ${user?.name ?? "Bambang"}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pindai QR / Barcode Nota',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(deliveriesProvider.notifier).loadDeliveries(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(deliveriesProvider.notifier).loadDeliveries(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Shift Duty Status Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isOnlineDuty
                          ? AppColors.successLight
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.two_wheeler_rounded,
                      color: _isOnlineDuty
                          ? AppColors.success
                          : AppColors.textMuted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                color: _isOnlineDuty
                                    ? AppColors.success
                                    : AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnlineDuty
                                  ? 'Siap Antar-Jemput'
                                  : 'Sedang Istirahat',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _isOnlineDuty
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Cabang Utama · Wilayah Denpasar & Sekitarnya',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isOnlineDuty,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _isOnlineDuty = val);
                      showSnack(
                        context,
                        val
                            ? 'Status kurir aktif. Siap menerima tugas.'
                            : 'Status kurir nonaktif / istirahat.',
                      );
                    },
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
                    label: 'Tugas Aktif',
                    value: '${state.activeCount}',
                    color: AppColors.primary,
                    bg: AppColors.primaryLight,
                    icon: Icons.assignment_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiTile(
                    label: 'Jemput',
                    value: '${state.pickupCount}',
                    color: const Color(0xFF0284C7),
                    bg: const Color(0xFFE0F2FE),
                    icon: Icons.pin_drop_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiTile(
                    label: 'Antar',
                    value: '${state.deliveryCount}',
                    color: const Color(0xFF8B5CF6),
                    bg: const Color(0xFFF3E8FF),
                    icon: Icons.local_shipping_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiTile(
                    label: 'Selesai',
                    value: '${state.completedCount}',
                    color: AppColors.success,
                    bg: AppColors.successLight,
                    icon: Icons.task_alt_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Tab Segmented Bar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _tabButton('Semua (${state.items.length})', 0),
                  ),
                  Expanded(
                    child: _tabButton('Jemput (${state.pickupCount})', 1),
                  ),
                  Expanded(
                    child: _tabButton('Antar (${state.deliveryCount})', 2),
                  ),
                  Expanded(
                    child: _tabButton('Selesai (${state.completedCount})', 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Daftar Tugas Kurir
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingView(message: 'Memuat tugas antar-jemput...'),
              )
            else if (filteredItems.isEmpty)
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
                        'Tidak ada tugas dalam kategori ini',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Semua paket dan cucian telah ditangani.',
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
              ...filteredItems.map((item) => _taskCard(item)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
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
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskCard(DeliveryModel item) {
    final isPickup = item.isPickup;
    final typeColor = isPickup ? const Color(0xFF0284C7) : const Color(0xFF8B5CF6);
    final order = item.order;
    final orderNo = order?.orderNo ?? 'LDRY-${item.orderId}';
    final custName = order?.customer?.name ?? 'Pelanggan';
    final custPhone = order?.customer?.phone ?? '08123456789';
    final address = order?.customer?.address ??
        (order?.notes != null && order!.notes!.contains('Alamat')
            ? order.notes!
            : 'Jl. Melati No. 12, Denpasar');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Header tipe & status
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPickup
                            ? Icons.pin_drop_rounded
                            : Icons.local_shipping_rounded,
                        size: 14,
                        color: typeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPickup ? 'JEMPUT CUCIAN' : 'ANTAR KE PELANGGAN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _statusPill(item),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Nomor order & Nama pelanggan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNo,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.fee > 0)
                  Text(
                    'Ongkir: ${Formatters.rupiah(item.fee)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              custName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            // Row 3: Alamat box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Row 4: Action quick shortcuts (WhatsApp & Maps & Order Detail)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showContactDialog(context, custName, custPhone),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                  label: Text(
                    'Hubungi',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showRouteDialog(context, custName, address, orderNo),
                  icon: const Icon(Icons.directions_rounded, size: 14),
                  label: Text(
                    'Rute',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    if (order != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(orderId: order.id)));
                    } else {
                      showSnack(context, 'Data detail order tidak tersedia.');
                    }
                  },
                  child: Text(
                    'Detail Order',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            // Row 5: Action Button (Mulai Jalan / Selesai)
            if (!item.isCompleted) ...[
              const Divider(height: 16),
              if (item.isPending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: typeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _updateStatus(
                      item,
                      'on_the_way',
                      isPickup ? 'Mulai Jemput' : 'Mulai Antar',
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: Text(
                      isPickup ? 'Mulai Jemput Cucian' : 'Mulai Antar Paket',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else if (item.isOnTheWay)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _updateStatus(
                      item,
                      'completed',
                      isPickup ? 'Selesai Dijemput' : 'Selesai Diantar',
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text(
                      isPickup
                          ? 'Konfirmasi Cucian Telah Dijemput'
                          : 'Konfirmasi Telah Diterima Pelanggan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(DeliveryModel item) {
    if (item.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 13, color: AppColors.success),
            const SizedBox(width: 4),
            Text(
              'Selesai',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    } else if (item.isOnTheWay) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.two_wheeler_rounded,
                size: 13, color: Color(0xFF0284C7)),
            const SizedBox(width: 4),
            Text(
              'Dalam Perjalanan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0284C7),
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
          children: [
            const Icon(Icons.schedule_rounded,
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

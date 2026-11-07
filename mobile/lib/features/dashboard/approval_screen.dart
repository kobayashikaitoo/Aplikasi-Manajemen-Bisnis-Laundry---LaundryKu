import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../orders/data/models.dart';
import '../orders/order_detail_screen.dart';
import 'approvals_provider.dart';

class ApprovalScreen extends ConsumerStatefulWidget {
  const ApprovalScreen({super.key});

  @override
  ConsumerState<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends ConsumerState<ApprovalScreen> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _refundCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  void _openApproveDialog(ApprovalModel item) {
    _noteCtrl.text = 'Disetujui oleh Pemilik toko.';
    if (item.amount > 0) {
      _refundCtrl.text = item.amount.toString();
    } else {
      _refundCtrl.clear();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Setujui Permintaan?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan menyetujui ${item.title} untuk pesanan ${item.orderNo}.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (item.sourceType == 'claim') ...[
              TextField(
                controller: _refundCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Kompensasi / Ganti Rugi (Rp)',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan Persetujuan (Opsional)',
                hintText: 'Tuliskan catatan untuk kasir atau pelanggan...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final refund = int.tryParse(_refundCtrl.text.trim());
              final ok = await ref.read(approvalsProvider.notifier).approve(
                    item.id,
                    notes: _noteCtrl.text.trim(),
                    refundAmount: refund,
                  );
              if (mounted) {
                if (ok) {
                  showSnack(context, 'Pengajuan #${item.orderNo} berhasil disetujui.');
                } else {
                  showSnack(context, 'Gagal memproses persetujuan.', isError: true);
                }
              }
            },
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );
  }

  void _openRejectDialog(ApprovalModel item) {
    _reasonCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tolak Permintaan?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tuliskan alasan penolakan secara jelas agar diketahui oleh pemohon.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan *',
                hintText: 'Contoh: Bukti foto kurang jelas / tidak memenuhi syarat garansi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = _reasonCtrl.text.trim();
              if (reason.length < 3) {
                showSnack(context, 'Alasan penolakan minimal 3 karakter.', isError: true);
                return;
              }
              Navigator.pop(ctx);
              final ok = await ref.read(approvalsProvider.notifier).reject(
                    item.id,
                    reason: reason,
                  );
              if (mounted) {
                if (ok) {
                  showSnack(context, 'Pengajuan #${item.orderNo} telah ditolak.');
                } else {
                  showSnack(context, 'Gagal menolak pengajuan.', isError: true);
                }
              }
            },
            child: const Text('Tolak Permintaan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(approvalsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Persetujuan & Otorisasi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(approvalsProvider.notifier).loadApprovals(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(approvalsProvider.notifier).loadApprovals(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _kpiTile(
                    label: 'Perlu Ditinjau',
                    value: '${state.pendingCount}',
                    color: AppColors.warning,
                    bg: AppColors.warningLight,
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiTile(
                    label: 'Disetujui',
                    value: '${state.approvedCount}',
                    color: AppColors.success,
                    bg: AppColors.successLight,
                    icon: Icons.verified_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiTile(
                    label: 'Ditolak',
                    value: '${state.rejectedCount}',
                    color: AppColors.danger,
                    bg: AppColors.dangerLight,
                    icon: Icons.cancel_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Status Filter Segmented Bar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _statusTab('Semua', 'all', state.statusFilter),
                  ),
                  Expanded(
                    child: _statusTab('Menunggu (${state.pendingCount})',
                        'pending', state.statusFilter),
                  ),
                  Expanded(
                    child: _statusTab('Disetujui', 'approved', state.statusFilter),
                  ),
                  Expanded(
                    child: _statusTab('Ditolak', 'rejected', state.statusFilter),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _categoryChip('Semua Kategori', 'all', state.categoryFilter),
                  const SizedBox(width: 8),
                  _categoryChip('Klaim Pelanggan', 'claim', state.categoryFilter),
                  const SizedBox(width: 8),
                  _categoryChip('Batal Order', 'cancel', state.categoryFilter),
                  const SizedBox(width: 8),
                  _categoryChip('Diskon Khusus', 'discount', state.categoryFilter),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Daftar Item Persetujuan
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingView(message: 'Memuat data persetujuan...'),
              )
            else if (state.items.isEmpty)
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
                          Icons.task_alt_rounded,
                          size: 32,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tidak ada permintaan persetujuan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Semua permohonan telah selesai diproses.',
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
              ...state.items.map((item) => _approvalCard(item)),
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

  Widget _statusTab(String label, String value, String current) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () =>
          ref.read(approvalsProvider.notifier).setStatusFilter(value),
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
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String value, String current) {
    final isSelected = current == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (_) =>
          ref.read(approvalsProvider.notifier).setCategoryFilter(value),
    );
  }

  Widget _approvalCard(ApprovalModel item) {
    final IconData catIcon;
    final Color catColor;

    switch (item.sourceType) {
      case 'claim':
        catIcon = Icons.shield_outlined;
        catColor = const Color(0xFF0284C7);
        break;
      case 'cancel':
        catIcon = Icons.cancel_outlined;
        catColor = AppColors.danger;
        break;
      case 'discount':
        catIcon = Icons.percent_rounded;
        catColor = const Color(0xFF8B5CF6);
        break;
      default:
        catIcon = Icons.verified_user_outlined;
        catColor = AppColors.primary;
    }

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
            // Row 1: Kategori & Status
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(catIcon, size: 14, color: catColor),
                      const SizedBox(width: 4),
                      Text(
                        item.categoryLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _statusPill(item),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Title & Order link
            Text(
              item.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            OrderDetailScreen(orderId: item.orderId)));
                  },
                  child: Row(
                    children: [
                      Text(
                        'Order #${item.orderNo}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 13, color: AppColors.primary),
                    ],
                  ),
                ),
                Text(
                  ' · ${item.customerName}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: Description box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keterangan & Alasan:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Row 4: Requester & Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pemohon: ${item.requesterName}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.amount > 0)
                  Text(
                    '${item.amountLabel}: ${Formatters.rupiah(item.amount)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),

            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tanggapan: ${item.notes}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            // Row 5: Action buttons if pending
            if (item.isPending) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _openRejectDialog(item),
                      child: Text(
                        'Tolak',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _openApproveDialog(item),
                      child: Text(
                        'Setujui',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(ApprovalModel item) {
    if (item.isApproved) {
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
              'Disetujui',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    } else if (item.isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded,
                size: 13, color: AppColors.danger),
            const SizedBox(width: 4),
            Text(
              'Ditolak',
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
          children: [
            const Icon(Icons.pending_rounded,
                size: 13, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              'Menunggu Otorisasi',
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

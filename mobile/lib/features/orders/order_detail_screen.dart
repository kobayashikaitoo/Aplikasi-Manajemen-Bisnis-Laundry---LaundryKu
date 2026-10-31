import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import 'claim_screen.dart';
import 'orders_providers.dart';
import 'data/models.dart';

String _photoBaseUrl() =>
    ApiConstants.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final user = ref.watch(authProvider).user;
    final isStaff = user != null && !user.isCustomer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (order) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(orderDetailProvider(orderId)),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              _NotaCard(order: order),
              _ItemsCard(order: order),
              if (isStaff) _CustomerCard(order: order),
              _PhotosCard(order: order, canUpload: isStaff),
              _TimelineCard(order: order),
              if (order.payments.isNotEmpty) _PaymentsCard(order: order),
              if (isStaff) _ActionsCard(order: order, isOwner: user.isOwner),
              // Klaim: tombol ajukan untuk pelanggan (Selesai), atau info status jika klaim sudah ada
              if ((!isStaff && order.status == 'Selesai') || order.hasClaim)
                _ClaimCard(order: order),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Nota + QR
class _NotaCard extends StatelessWidget {
  final OrderModel order;
  const _NotaCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NOTA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary)),
              StatusChip(status: order.status),
            ],
          ),
          const Divider(height: 24),
          Text(order.orderNo,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          QrImageView(
            data: order.barcode,
            size: 150,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 6),
          Text(order.barcode,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text('Dibuat: ${Formatters.dateTimeWita(order.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (order.completedAt != null)
            Text('Selesai dicuci: ${Formatters.dateTimeWita(order.completedAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (order.dueAt != null)
            Text('Batas ambil: ${Formatters.dateTimeWita(order.dueAt)}',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Item list
class _ItemsCard extends StatelessWidget {
  final OrderModel order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian layanan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          ...order.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.serviceNameSnap,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                            '${it.quantityLabel} × ${Formatters.rupiah(it.unitPrice)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Text(Formatters.rupiah(it.subtotal),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          _sumRow('Subtotal', order.subtotal),
          if (order.discountAmount > 0)
            _sumRow('Diskon', -order.discountAmount,
                color: AppColors.success),
          _sumRow('Total', order.totalAmount, bold: true),
          if (order.totalPaid > 0) ...[
            const SizedBox(height: 6),
            _sumRow('Dibayar', order.totalPaid, color: AppColors.info),
            _sumRow('Sisa tagihan', order.remainingBalance,
                color: order.remainingBalance > 0 ? AppColors.danger : AppColors.success),
          ],
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Catatan: ${order.notes}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _sumRow(String label, int amount,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: AppColors.textSecondary)),
          Text(Formatters.rupiah(amount),
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? AppColors.primary : (color ?? AppColors.textPrimary))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Customer
class _CustomerCard extends StatelessWidget {
  final OrderModel order;
  const _CustomerCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = order.customer;
    if (c == null) return const SizedBox.shrink();
    return SectionCard(
      child: Row(
        children: [
          const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person_rounded, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${c.phone} · ${c.pointBalance} poin',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Photos
class _PhotosCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final bool canUpload;

  const _PhotosCard({required this.order, required this.canUpload});

  @override
  ConsumerState<_PhotosCard> createState() => _PhotosCardState();
}

class _PhotosCardState extends ConsumerState<_PhotosCard> {
  bool _uploading = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 1280, imageQuality: 70);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await ref
          .read(laundryRepositoryProvider)
          .uploadPhoto(widget.order.id, dataUri);
      ref.invalidate(orderDetailProvider(widget.order.id));
      if (mounted) showSnack(context, 'Foto kondisi awal tersimpan.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Tidak dapat mengakses kamera. Gunakan input manual bila perlu.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.order.photos.where((p) => p.photoType == 'initial').toList();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Foto kondisi awal',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (photos.isEmpty && widget.order.status == 'Diterima')
                const Text('Wajib sebelum Ditimbang',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 10),
          if (photos.isEmpty)
            TextButton.icon(
              onPressed: widget.canUpload && !_uploading ? _takePhoto : null,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera_rounded),
              label: const Text('Ambil foto'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...photos.map((p) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _photoBaseUrl() + p.photoPath,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 84,
                          height: 84,
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.broken_image_rounded,
                              color: AppColors.primary),
                        ),
                      ),
                    )),
                if (widget.canUpload)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _uploading ? null : _takePhoto,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Timeline helpers

/// Standard main-flow lifecycle steps (in order).
const _kLifecycleSteps = <String>[
  'Diterima',
  'Ditimbang',
  'Dicuci',
  'Disetrika',
  'Siap',
  'Diambil',
  'Lunas',
  'Selesai',
];

/// Compact date+time label for the timeline, e.g. "Sab, 10 Okt · 09.12"
String _timelineDate(String? dateStr) {
  if (dateStr == null) return '-';
  try {
    final dt = DateTime.parse(dateStr).toUtc().add(const Duration(hours: 8));
    return DateFormat("EEE, d MMM '·' HH.mm", 'id_ID').format(dt);
  } catch (_) {
    return '-';
  }
}

// ---------------------------------------------------------------- Timeline card
class _TimelineCard extends StatelessWidget {
  final OrderModel order;
  const _TimelineCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final currentStatus = order.status;
    final isSpecialTerminal =
        currentStatus == 'Dibatalkan' || currentStatus == 'Tidak Diambil';

    // Build map: toStatus → first StatusLogModel that reached it
    final logMap = <String, StatusLogModel>{};
    for (final log in order.statusLogs) {
      logMap.putIfAbsent(log.toStatus, () => log);
    }

    // Determine which steps to render
    final List<String> steps;
    if (isSpecialTerminal) {
      // Show only lifecycle steps that were actually reached, plus the terminal
      var lastReachedIdx = -1;
      for (var i = 0; i < _kLifecycleSteps.length; i++) {
        if (logMap.containsKey(_kLifecycleSteps[i])) lastReachedIdx = i;
      }
      steps = [
        if (lastReachedIdx >= 0)
          ..._kLifecycleSteps.sublist(0, lastReachedIdx + 1),
        currentStatus,
      ];
    } else {
      steps = _kLifecycleSteps;
    }

    final currentIdx = steps.indexOf(currentStatus);

    // Find initial-condition photo (linked to "Ditimbang" step)
    OrderPhotoModel? initialPhoto;
    for (final p in order.photos) {
      if (p.photoType == 'initial') {
        initialPhoto = p;
        break;
      }
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Linimasa status',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final stepName = entry.value;
            final isCompleted = idx < currentIdx;
            final isActive = idx == currentIdx;
            final isLast = idx == steps.length - 1;
            final log = logMap[stepName];
            final showPhotoLink =
                stepName == 'Ditimbang' && initialPhoto != null;

            return _StepRow(
              stepName: stepName,
              isCompleted: isCompleted,
              isActive: isActive,
              isLast: isLast,
              log: log,
              showPhotoLink: showPhotoLink,
              photoUrl: showPhotoLink
                  ? (_photoBaseUrl() + initialPhoto.photoPath)
                  : null,
              order: order,
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Individual step row
class _StepRow extends StatelessWidget {
  final String stepName;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;
  final StatusLogModel? log;
  final bool showPhotoLink;
  final String? photoUrl;
  final OrderModel order;

  const _StepRow({
    required this.stepName,
    required this.isCompleted,
    required this.isActive,
    required this.isLast,
    this.log,
    required this.showPhotoLink,
    this.photoUrl,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = isCompleted ? AppColors.primary : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Left column: dot + connecting line ----
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _TimelineDot(isCompleted: isCompleted, isActive: isActive),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: lineColor),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ---- Right column: text content ----
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step name + optional "Sekarang" badge
                  Row(
                    children: [
                      Text(
                        stepName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : isCompleted
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                          color: isCompleted || isActive
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Sekarang',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Subtitle
                  if (isCompleted || isActive)
                    _completedSubtitle(context)
                  else
                    _pendingSubtitle(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedSubtitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _timelineDate(log?.createdAt),
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        if (showPhotoLink && photoUrl != null)
          GestureDetector(
            onTap: () => _openPhotoDialog(context, photoUrl!),
            child: const Text(
              'Foto kondisi awal',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _pendingSubtitle() {
    String label;
    if (stepName == 'Siap' && order.completedAt != null) {
      label =
          'Perkiraan ${_timelineDate(order.completedAt)}. Anda akan dapat notifikasi.';
    } else if (order.dueAt != null) {
      label = 'Perkiraan ${_timelineDate(order.dueAt)}.';
    } else {
      label = 'Menunggu proses sebelumnya selesai.';
    }
    return Text(
      label,
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    );
  }

  void _openPhotoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        clipBehavior: Clip.antiAlias,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(32),
                child: Icon(Icons.broken_image_rounded,
                    size: 56, color: AppColors.textMuted),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black38,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Tutup',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Dot indicator
class _TimelineDot extends StatelessWidget {
  final bool isCompleted;
  final bool isActive;
  const _TimelineDot({required this.isCompleted, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      // Solid teal circle with white checkmark
      return Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(top: 1),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
      );
    }
    if (isActive) {
      // Amber circle with thick border and inner dot
      return Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 3),
          color: Colors.white,
        ),
        child: Center(
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    // Pending: hollow gray circle
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
        color: Colors.white,
      ),
    );
  }
}

// ---------------------------------------------------------------- Payments
class _PaymentsCard extends StatelessWidget {
  final OrderModel order;
  const _PaymentsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pembayaran',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...order.payments.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${p.paymentMethod == 'cash' ? 'Tunai' : 'Transfer'} · ${Formatters.dateTimeWita(p.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text('+ ${Formatters.rupiah(p.amount)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Actions
class _ActionsCard extends ConsumerWidget {
  final OrderModel order;
  final bool isOwner;

  const _ActionsCard({required this.order, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = kAllowedTransitions[order.status] ?? [];
    final canPay = order.remainingBalance > 0 &&
        !order.isClosed &&
        order.status != 'Diterima' &&
        order.status != 'Ditimbang' &&
        order.status != 'Dicuci' &&
        order.status != 'Disetrika';
    final showDibatalkan = isOwner; // pegawai butuh persetujuan pemilik

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Aksi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          if (next.isEmpty && !canPay)
            const Text('Order sudah pada status akhir.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...next.where((s) => s != 'Dibatalkan' || showDibatalkan).map(
                      (s) => ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: s == 'Dibatalkan'
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                        onPressed: () => _onTransition(context, ref, s),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text('→ $s'),
                      ),
                    ),
                if (canPay)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    onPressed: () => showPaymentSheet(context, ref, order),
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: Text(
                        'Catat pembayaran (${Formatters.rupiah(order.remainingBalance)})'),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          const Text(
            'Hanya transisi yang diizinkan yang ditampilkan. Pengembalian status khusus pemilik dengan alasan tertulis.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _onTransition(
      BuildContext context, WidgetRef ref, String target) async {
    String? reason;
    if (target == 'Siap') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tandai Siap?'),
          content: const Text(
              'Menandai Siap akan mengirim notifikasi ke pelanggan dan memulai batas pengambilan 7 hari.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tandai Siap')),
          ],
        ),
      );
      if (confirmed != true) return;
    } else if (target == 'Dibatalkan') {
      reason = await _askReason(context, 'Alasan pembatalan (wajib)');
      if (reason == null || reason.isEmpty) return;
    }

    try {
      await ref
          .read(laundryRepositoryProvider)
          .updateStatus(order.id, target, reason: reason);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersListProvider);
      if (context.mounted) showSnack(context, 'Status berubah menjadi $target.');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, isError: true);
    }
  }
}

Future<String?> _askReason(BuildContext context, String label) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Tulis alasan...'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kirim')),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Claim Card (Customer only, status Selesai)
class _ClaimCard extends StatelessWidget {
  final OrderModel order;
  const _ClaimCard({required this.order});

  bool get _withinDeadline {
    final completed = order.completedAt;
    if (completed == null) return false;
    try {
      final dt = DateTime.parse(completed);
      return DateTime.now().isBefore(dt.add(const Duration(days: 7)));
    } catch (_) {
      return false;
    }
  }

  String get _deadlineText {
    final completed = order.completedAt;
    if (completed == null) return '';
    try {
      final dt = DateTime.parse(completed).add(const Duration(days: 7));
      return DateFormat("d MMM, HH.mm", 'id_ID').format(dt.toLocal());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = order.activeClaim;
    if (claim != null) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status Klaim',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                StatusChip(status: claim.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Jenis masalah: ${claim.claimType}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              claim.description,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (claim.resolution != null && claim.resolution!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tanggapan: ${claim.resolution}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
            if (claim.refundAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Refund: ${Formatters.rupiah(claim.refundAmount)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
              ),
            ],
          ],
        ),
      );
    }

    final within = _withinDeadline;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ajukan Klaim',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (within && _deadlineText.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Batas s.d. $_deadlineText',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            within
                ? 'Ada masalah dengan cucian Anda? Ajukan klaim sebelum masa klaim habis.'
                : 'Masa pengajuan klaim untuk order ini sudah habis (7 hari setelah selesai).',
            style: TextStyle(
              fontSize: 12,
              color: within ? AppColors.textSecondary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    within ? AppColors.accent : AppColors.textMuted,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: within
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClaimScreen(order: order),
                        ),
                      )
                  : null,
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: const Text(
                'Ajukan Klaim',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Payment sheet
Future<void> showPaymentSheet(
    BuildContext context, WidgetRef ref, OrderModel order) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: _PaymentForm(order: order, sheetContext: ctx),
    ),
  );
}

class _PaymentForm extends ConsumerStatefulWidget {
  final OrderModel order;
  final BuildContext sheetContext;

  const _PaymentForm({required this.order, required this.sheetContext});

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  late final TextEditingController _amountCtrl;
  String _method = 'cash';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: '${widget.order.remainingBalance}');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (_amount <= 0) {
      showSnack(context, 'Jumlah pembayaran tidak valid.', isError: true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      // Idempotency key prevents double posting on retry
      final key =
          'pay-${widget.order.id}-${DateTime.now().millisecondsSinceEpoch}';
      await ref.read(laundryRepositoryProvider).recordPayment(
            orderId: widget.order.id,
            amount: _amount,
            method: _method,
            idempotencyKey: key,
          );
      ref.invalidate(orderDetailProvider(widget.order.id));
      ref.invalidate(ordersListProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Pembayaran ${Formatters.rupiah(_amount)} tercatat.'),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final expectedPoints = order.totalAmount ~/ 10000;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Catat Pembayaran · ${order.orderNo}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(order.customer?.name ?? '',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total order', style: TextStyle(fontSize: 13)),
            Text(Formatters.rupiah(order.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        if (order.totalPaid > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dibayar', style: TextStyle(fontSize: 13)),
              Text('− ${Formatters.rupiah(order.totalPaid)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.info)),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sisa tagihan', style: TextStyle(fontSize: 13)),
            Text(Formatters.rupiah(order.remainingBalance),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.danger)),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'cash',
                label: Text('Tunai'),
                icon: Icon(Icons.payments_rounded)),
            ButtonSegment(
                value: 'transfer',
                label: Text('Transfer'),
                icon: Icon(Icons.account_balance_rounded)),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Jumlah dibayar (Rp)',
            prefixIcon: Icon(Icons.money_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final nominal in [50000, 100000, order.remainingBalance])
              if (nominal > 0)
                ActionChip(
                  label: Text(Formatters.rupiah(nominal)),
                  onPressed: () =>
                      setState(() => _amountCtrl.text = '$nominal'),
                ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Status setelah dicatat lunas: Lunas → Selesai. Poin pelanggan +$expectedPoints.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text('Catat pembayaran ${Formatters.rupiah(_amount)}'),
        ),
      ],
    );
  }
}

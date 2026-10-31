import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import 'orders_providers.dart';
import 'data/models.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kClaimTypes = <String>[
  'Pakaian rusak / sobek',
  'Noda tidak hilang',
  'Item kurang / hilang',
  'Lainnya',
];

// ---------------------------------------------------------------------------
// ClaimScreen
// ---------------------------------------------------------------------------

class ClaimScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const ClaimScreen({super.key, required this.order});

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  final _descCtrl = TextEditingController();
  String? _selectedType;
  final List<File> _photos = [];
  bool _submitting = false;

  // Deadline klaim: 7 hari setelah completedAt
  DateTime? get _claimDeadline {
    final completed = widget.order.completedAt;
    if (completed == null) return null;
    try {
      final dt = DateTime.parse(completed);
      return dt.add(const Duration(days: 7));
    } catch (_) {
      return null;
    }
  }

  bool get _isWithinDeadline {
    final deadline = _claimDeadline;
    if (deadline == null) return false;
    return DateTime.now().isBefore(deadline);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ---- Photo Picker ----
  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) {
      showSnack(context, 'Maksimal 3 foto pendukung.', isError: true);
      return;
    }

    final source = await _showSourceSheet();
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (file == null) return;
    setState(() => _photos.add(File(file.path)));
  }

  Future<ImageSource?> _showSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const Text('Ambil foto dengan kamera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removePhoto(int idx) => setState(() => _photos.removeAt(idx));

  // ---- Submit ----
  Future<void> _submit() async {
    if (_selectedType == null) {
      showSnack(context, 'Pilih jenis masalah terlebih dahulu.', isError: true);
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      showSnack(context, 'Ceritakan masalahnya terlebih dahulu.', isError: true);
      return;
    }
    if (!_isWithinDeadline) {
      // Pesan disesuaikan: jika completedAt null (tidak mungkin di status Selesai)
      // vs benar-benar sudah expired
      final msg = widget.order.completedAt == null
          ? 'Order belum selesai diproses.'
          : 'Masa klaim untuk order ini sudah habis (7 hari setelah selesai).';
      showSnack(context, msg, isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      // Encode photos ke base64
      final List<String> base64Photos = [];
      for (final f in _photos) {
        final bytes = await f.readAsBytes();
        base64Photos.add('data:image/jpeg;base64,${base64Encode(bytes)}');
      }

      await ref.read(laundryRepositoryProvider).submitClaim(
            orderId: widget.order.id,
            claimType: _selectedType!,
            description: desc,
            photoBase64List: base64Photos.isNotEmpty ? base64Photos : null,
          );

      // Invalidasi provider agar list order/detail terupdate
      ref.invalidate(orderDetailProvider(widget.order.id));
      ref.invalidate(ordersListProvider);

      if (mounted) {
        showSnack(context, 'Klaim berhasil diajukan! Kami akan segera meninjau.');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Terjadi kesalahan. Silakan coba lagi.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajukan Klaim'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 32,
        ),
        children: [
          _OrderHeaderCard(order: widget.order, deadline: _claimDeadline),
          const SizedBox(height: 20),
          _ClaimTypeSection(
            selected: _selectedType,
            onSelect: (t) => setState(() => _selectedType = t),
          ),
          const SizedBox(height: 20),
          _DescriptionSection(controller: _descCtrl),
          const SizedBox(height: 20),
          _PhotoSection(
            photos: _photos,
            onAdd: _pickPhoto,
            onRemove: _removePhoto,
          ),
          const SizedBox(height: 16),
          const _InfoBox(),
          const SizedBox(height: 20),
          const _ClaimStatusStepper(),
          const SizedBox(height: 28),
        ],
      ),
      bottomNavigationBar: _SubmitBar(
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order Header Card
// ---------------------------------------------------------------------------

class _OrderHeaderCard extends StatelessWidget {
  final OrderModel order;
  final DateTime? deadline;

  const _OrderHeaderCard({required this.order, this.deadline});

  String _formatDeadline(DateTime dt) {
    // e.g. "s.d. 12 Okt, 15.00"
    return 's.d. ${DateFormat("d MMM, HH.mm", "id_ID").format(dt.toLocal())}';
  }

  String _buildSummary() {
    if (order.items.isEmpty) return order.orderNo;
    final first = order.items.first;
    final typeName = first.unitSnap == 'kg' ? 'Kiloan' : 'Satuan';
    final totalPcs = order.items.fold<double>(0, (s, i) => s + i.quantity);
    final pcsLabel =
        first.unitSnap == 'kg' ? '${totalPcs.toStringAsFixed(1)} kg' : '${totalPcs.toInt()} pcs';
    final completedStr = order.completedAt != null
        ? 'Selesai ${DateFormat("d MMM, HH.mm", "id_ID").format(DateTime.parse(order.completedAt!).toLocal())}'
        : 'Selesai';
    return '$typeName · $pcsLabel · $completedStr';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kiri: nomor order + ringkasan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _buildSummary(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Kanan: badge masa klaim
          if (deadline != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Masa klaim',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDeadline(deadline!),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jenis Masalah Section
// ---------------------------------------------------------------------------

class _ClaimTypeSection extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ClaimTypeSection({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jenis masalah',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kClaimTypes.map((type) {
            final isSelected = selected == type;
            return GestureDetector(
              onTap: () => onSelect(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.8 : 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Deskripsi Masalah Section
// ---------------------------------------------------------------------------

class _DescriptionSection extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ceritakan masalahnya',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Contoh: kemeja putih ada sobekan di bagian lengan kiri.',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.6),
            ),
          ),
          style: const TextStyle(fontSize: 13),
          textInputAction: TextInputAction.newline,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Foto Pendukung Section
// ---------------------------------------------------------------------------

class _PhotoSection extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotoSection({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto pendukung',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: Row(
            children: [
              // Tombol tambah — dashed border (hanya tampil jika foto < 3)
              if (photos.length < 3) ...[
                _AddPhotoButton(onTap: onAdd),
                const SizedBox(width: 10),
              ],
              // Slot foto yang sudah dipilih (maks 3)
              ...photos.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _PhotoThumbnail(
                    file: entry.value,
                    onRemove: () => onRemove(entry.key),
                  ),
                );
              }),
              // Slot placeholder kosong — total slot: add_btn + photos + placeholders = 3
              // Jika photos.length < 3: tampilkan (2 - photos.length) placeholder
              // Jika photos.length == 3: tidak ada placeholder (add button tersembunyi)
              if (photos.length < 3)
                ...List.generate(
                  (2 - photos.length).clamp(0, 2),
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: _EmptyPhotoSlot(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: AppColors.primary),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 24, color: AppColors.primary),
                SizedBox(height: 3),
                Text(
                  'Tambah',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter untuk dashed border sesuai mockup
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = 12.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    final dashPath = _dashPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source, double dashWidth, double dashSpace) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final start = dist;
        dist += dashWidth;
        dest.addPath(
          metric.extractPath(start, dist),
          Offset.zero,
        );
        dist += dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

class _PhotoThumbnail extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _PhotoThumbnail({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFF3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.image_rounded,
        size: 28,
        color: Color(0xFF9BAFBA),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info Box
// ---------------------------------------------------------------------------

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE), // AppColors.infoLight
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tim kami membandingkan laporan Anda dengan foto kondisi awal saat cucian diterima. Anda dapat notifikasi di setiap perubahan status klaim.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.info,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Stepper (visual only)
// ---------------------------------------------------------------------------

class _ClaimStatusStepper extends StatelessWidget {
  const _ClaimStatusStepper();

  static const _steps = [
    'Diajukan',
    'Ditinjau',
    'Disetujui / Ditolak',
    'Selesai',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _steps.asMap().entries.expand((entry) {
        final idx = entry.key;
        final label = entry.value;
        final isFirst = idx == 0; // "Diajukan" = aktif saat baru mengajukan
        final isLast = idx == _steps.length - 1;

        final widgets = <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  isFirst ? FontWeight.w700 : FontWeight.w500,
              color: isFirst ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ];

        if (!isLast) {
          widgets.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '›',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ));
        }
        return widgets;
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Submit Bar
// ---------------------------------------------------------------------------

class _SubmitBar extends StatelessWidget {
  final bool submitting;
  final VoidCallback onSubmit;

  const _SubmitBar({required this.submitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent, // #B75307 terracotta
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Kirim klaim',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

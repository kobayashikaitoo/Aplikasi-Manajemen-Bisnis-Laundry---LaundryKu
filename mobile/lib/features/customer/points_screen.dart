import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import '../orders/data/models.dart';
import '../orders/orders_providers.dart';

/// Halaman Poin Member Pelanggan sesuai Mockup Halaman 5.
class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null || user.customerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Poin Member')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_border_rounded, size: 56, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text('Data profil pelanggan sedang dimuat...'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(authProvider.notifier).refreshUser(),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final pointsAsync = ref.watch(pointsProvider(user.customerId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poin Member'),
      ),
      body: pointsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(pointsProvider(user.customerId!)),
        ),
        data: (points) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(pointsProvider(user.customerId!)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // 1. Hero Saldo Poin
              _BalanceHeroCard(pointBalance: points.pointBalance),
              const SizedBox(height: 24),

              // 2. Seksi Tukar Poin
              _RedeemSection(
                currentPoints: points.pointBalance,
                customerId: user.customerId!,
              ),

              // 3. Seksi Riwayat Poin
              _HistorySection(transactions: points.transactions),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Hero Card
class _BalanceHeroCard extends StatelessWidget {
  final int pointBalance;
  const _BalanceHeroCard({required this.pointBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo poin Anda',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$pointBalance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'poin',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.22), height: 1),
          const SizedBox(height: 14),
          Text(
            'Poin diberikan setelah order lunas: 1 poin untuk setiap Rp10.000 yang dibayar.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Seksi Tukar Poin
class _VoucherItem {
  final String title;
  final int pointsRequired;
  final int nominalRupiah;

  const _VoucherItem({
    required this.title,
    required this.pointsRequired,
    required this.nominalRupiah,
  });
}

const _kVouchers = [
  _VoucherItem(title: 'Potongan Rp5.000', pointsRequired: 50, nominalRupiah: 5000),
  _VoucherItem(title: 'Potongan Rp10.000', pointsRequired: 100, nominalRupiah: 10000),
  _VoucherItem(title: 'Potongan Rp15.000', pointsRequired: 150, nominalRupiah: 15000),
];

class _RedeemSection extends StatelessWidget {
  final int currentPoints;
  final int customerId;
  const _RedeemSection({
    required this.currentPoints,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tukar poin',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._kVouchers.map((voucher) {
          final isLocked = currentPoints < voucher.pointsRequired;
          final lacking = voucher.pointsRequired - currentPoints;

          if (isLocked) {
            return _LockedVoucherCard(voucher: voucher, lacking: lacking);
          }
          return _UnlockedVoucherCard(
            voucher: voucher,
            customerId: customerId,
          );
        }),
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 2, bottom: 22),
          child: Text(
            'Potongan otomatis dipakai pada order berikutnya.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnlockedVoucherCard extends ConsumerWidget {
  final _VoucherItem voucher;
  final int customerId;
  const _UnlockedVoucherCard({
    required this.voucher,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voucher.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${voucher.pointsRequired} poin',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showRedeemDialog(context, ref, voucher),
            child: const Text(
              'Tukar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(
      BuildContext context, WidgetRef ref, _VoucherItem voucher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Tukar ${voucher.pointsRequired} Poin?'),
        content: Text(
          'Anda akan menukarkan ${voucher.pointsRequired} poin untuk ${voucher.title}.\n\nSaldo poin akan terpotong secara permanen di database dan tercatat di riwayat penukaran Anda.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(laundryRepositoryProvider).redeemPoints(
                      customerId: customerId,
                      points: voucher.pointsRequired,
                      description: 'Tukar ${voucher.title}',
                    );
                ref.invalidate(pointsProvider(customerId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                'Voucher ${voucher.title} berhasil ditukar! Saldo poin Anda telah diperbarui.'),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } on ApiException catch (e) {
                if (context.mounted) {
                  showSnack(context, e.message, isError: true);
                }
              } catch (_) {
                if (context.mounted) {
                  showSnack(context, 'Gagal menukarkan poin. Coba lagi.',
                      isError: true);
                }
              }
            },
            child: const Text('Tukar Sekarang',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _LockedVoucherCard extends StatelessWidget {
  final _VoucherItem voucher;
  final int lacking;
  const _LockedVoucherCard({required this.voucher, required this.lacking});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.borderSubtle,
          strokeWidth: 1.2,
          radius: 16,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${voucher.pointsRequired} poin · kurang $lacking poin',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Poin Anda belum cukup. Kumpulkan $lacking poin lagi dari transaksi cucian Anda.'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: const Text(
                  'Terkunci',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Seksi Riwayat Poin
class _HistorySection extends StatelessWidget {
  final List<LoyaltyTransactionModel> transactions;
  const _HistorySection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riwayat poin',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi poin.',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                )
              : Column(
                  children: transactions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    final isEarn = t.type == 'earn';
                    final isLast = idx == transactions.length - 1;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getTitle(t),
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _getSubtitle(t),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isEarn ? '+' : '−'}${t.points}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isEarn
                                      ? AppColors.success
                                      : AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.border),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  String _getTitle(LoyaltyTransactionModel t) {
    if (t.type == 'earn') {
      return 'Order lunas';
    } else {
      return 'Tukar potongan';
    }
  }

  String _getSubtitle(LoyaltyTransactionModel t) {
    final desc = t.description ?? '';
    final match =
        RegExp(r'(LDRY-[A-Za-z0-9\-]+|LK-[A-Za-z0-9\-]+)').firstMatch(desc);
    final orderCode = match?.group(0);
    final dateStr = _formatShortDate(t.createdAt);

    if (orderCode != null) {
      return '$orderCode · $dateStr';
    }
    return dateStr;
  }

  String _formatShortDate(String? createdAt) {
    if (createdAt == null) return '-';
    try {
      final dt =
          DateTime.parse(createdAt).toUtc().add(const Duration(hours: 8));
      return DateFormat('d MMM', 'id_ID').format(dt);
    } catch (_) {
      return '-';
    }
  }
}

// ---------------------------------------------------------------- Dashed Border Painter
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  static const double _dash = 5.0;
  static const double _gap = 3.5;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + _dash > metric.length)
            ? metric.length - distance
            : _dash;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      radius != oldDelegate.radius;
}

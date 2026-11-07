import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/ui_kit.dart';
import '../auth/auth_controller.dart';
import 'orders_providers.dart';
import 'order_detail_screen.dart';
import 'sync_queue_provider.dart';
import 'sync_queue_screen.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = ref.watch(authProvider).user?.isCustomer ?? false;
    final filter = ref.watch(ordersFilterProvider);
    final ordersAsync = ref.watch(ordersListProvider);

    final statuses = <String>['', ...kOrderStatusFlow, 'Tidak Diambil', 'Dibatalkan'];

    final syncQueue = ref.watch(syncQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan'),
        actions: [
          if (!isCustomer)
            IconButton(
              tooltip: 'Antrean Sinkronisasi Kasir',
              icon: Badge(
                isLabelVisible: syncQueue.pendingCount > 0,
                label: Text('${syncQueue.pendingCount}'),
                backgroundColor: AppColors.warning,
                child: const Icon(Icons.cloud_sync_rounded),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncQueueScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(ordersListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari nomor order, pelanggan, atau telepon',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: filter.search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref
                            .read(ordersFilterProvider.notifier)
                            .setSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: (v) =>
                ref.read(ordersFilterProvider.notifier).setSearch(v),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: statuses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = statuses[i];
              final selected = filter.status == s;
              return FilterChip(
                label: Text(s.isEmpty ? 'Semua' : s),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                onSelected: (_) => ref
                    .read(ordersFilterProvider.notifier)
                    .setStatus(s),
              );
            },
          ),
        ),
        Expanded(
          child: ordersAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(ordersListProvider),
            ),
            data: (orders) {
              if (orders.isEmpty) {
                return const EmptyView(
                  icon: Icons.receipt_long_rounded,
                  message:
                      'Belum ada order. Tarik data atau buat order baru.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(ordersListProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    return SectionCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: o.id)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(o.orderNo,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.textPrimary)),
                              ),
                              StatusChip(status: o.status, dense: true),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.customer?.name ?? 'Pelanggan',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                              Text(Formatters.rupiah(o.totalAmount),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            o.items.map((e) => e.quantityLabel).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                          if (o.createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(Formatters.dateWita(o.createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}

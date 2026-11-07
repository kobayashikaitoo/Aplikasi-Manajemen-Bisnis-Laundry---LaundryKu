import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/laundry_repository.dart';
import 'data/models.dart';
import 'orders_providers.dart';

class SyncQueueState {
  final bool isOnline;
  final int latencyMs;
  final bool isSyncing;
  final List<SyncQueueItem> items;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const SyncQueueState({
    this.isOnline = true,
    this.latencyMs = 38,
    this.isSyncing = false,
    this.items = const [],
    this.lastSyncedAt,
    this.errorMessage,
  });

  int get pendingCount => items.where((i) => i.isPending).count;
  int get syncedCount => items.where((i) => i.isSynced).count;
  int get failedCount => items.where((i) => i.isFailed).count;

  SyncQueueState copyWith({
    bool? isOnline,
    int? latencyMs,
    bool? isSyncing,
    List<SyncQueueItem>? items,
    DateTime? lastSyncedAt,
    String? errorMessage,
  }) =>
      SyncQueueState(
        isOnline: isOnline ?? this.isOnline,
        latencyMs: latencyMs ?? this.latencyMs,
        isSyncing: isSyncing ?? this.isSyncing,
        items: items ?? this.items,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        errorMessage: errorMessage,
      );
}

class SyncQueueNotifier extends StateNotifier<SyncQueueState> {
  final LaundryRepository _repo;
  static const String _kStorageKey = 'laundryku_sync_queue';

  SyncQueueNotifier(this._repo) : super(const SyncQueueState()) {
    _loadFromStorage();
    checkConnection();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        final loaded = list.map((e) => SyncQueueItem.fromJson(e)).toList();
        state = state.copyWith(items: loaded);
      } else {
        // Sample default queue items to make the cashier screen informative right away
        final defaultItems = [
          SyncQueueItem(
            id: 'SYNC-101',
            actionType: 'UPDATE_STATUS',
            title: 'Update Status Cucian ke Ditimbang',
            orderNo: 'LDRY-20261019-0001',
            customerName: 'Budi Santoso',
            amount: 0,
            status: 'synced',
            queuedAt: DateTime.now().subtract(const Duration(hours: 2)),
            syncedAt: DateTime.now().subtract(const Duration(hours: 2)),
            payload: {'status': 'Ditimbang', 'order_id': 1},
          ),
          SyncQueueItem(
            id: 'SYNC-102',
            actionType: 'PAYMENT',
            title: 'Penerimaan Pembayaran Tunai',
            orderNo: 'LDRY-20261019-0002',
            customerName: 'Siti Rahma',
            amount: 45000,
            status: 'synced',
            queuedAt: DateTime.now().subtract(const Duration(minutes: 45)),
            syncedAt: DateTime.now().subtract(const Duration(minutes: 45)),
            payload: {'amount': 45000, 'method': 'cash'},
          ),
        ];
        state = state.copyWith(items: defaultItems);
        _saveToStorage(defaultItems);
      }
    } catch (_) {
      // Ignore storage loading error
    }
  }

  Future<void> _saveToStorage(List<SyncQueueItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_kStorageKey, jsonStr);
    } catch (_) {}
  }

  Future<void> checkConnection() async {
    final sw = Stopwatch()..start();
    try {
      await _repo.fetchSyncStatus();
      sw.stop();
      state = state.copyWith(
        isOnline: true,
        latencyMs: sw.elapsedMilliseconds.clamp(15, 999),
      );
    } catch (_) {
      sw.stop();
      state = state.copyWith(isOnline: false, latencyMs: 0);
    }
  }

  Future<void> enqueueItem(SyncQueueItem item) async {
    final updated = [item, ...state.items];
    state = state.copyWith(items: updated);
    await _saveToStorage(updated);
  }

  Future<void> simulateOfflineOrder() async {
    final now = DateTime.now();
    final tempNo = 'LDRY-OFF-${now.minute}${now.second}';
    final newItem = SyncQueueItem(
      id: 'QUEUE-${DateTime.now().millisecondsSinceEpoch}',
      actionType: 'CREATE_ORDER',
      title: 'Input Pesanan Kasir (Offline Queue)',
      orderNo: tempNo,
      customerName: 'Pelanggan Walk-in Offline',
      amount: 32000,
      status: 'pending',
      queuedAt: now,
      payload: {
        'order_no': tempNo,
        'customer': 'Pelanggan Walk-in Offline',
        'items': [
          {'service': 'Cuci Kiloan Reguler', 'qty': 4.0, 'subtotal': 32000}
        ],
        'note': 'Antrean dicatat saat POS kasir offline',
      },
    );

    await enqueueItem(newItem);
  }

  Future<void> syncAll() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      // Simulate real sync processing with the server
      await checkConnection();
      await Future.delayed(const Duration(milliseconds: 900));

      final updated = state.items.map((item) {
        if (item.isPending || item.isFailed) {
          return item.copyWith(
            status: 'synced',
            syncedAt: DateTime.now(),
            errorMessage: null,
          );
        }
        return item;
      }).toList();

      state = state.copyWith(
        isSyncing: false,
        items: updated,
        lastSyncedAt: DateTime.now(),
      );
      await _saveToStorage(updated);
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Gagal melakukan sinkronisasi: $e',
      );
    }
  }

  Future<void> retryItem(String id) async {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(
          status: 'synced',
          syncedAt: DateTime.now(),
          errorMessage: null,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
    await _saveToStorage(updated);
  }

  Future<void> removeItem(String id) async {
    final updated = state.items.where((item) => item.id != id).toList();
    state = state.copyWith(items: updated);
    await _saveToStorage(updated);
  }

  Future<void> clearSynced() async {
    final remaining = state.items.where((i) => !i.isSynced).toList();
    state = state.copyWith(items: remaining);
    await _saveToStorage(remaining);
  }
}

final syncQueueProvider =
    StateNotifierProvider<SyncQueueNotifier, SyncQueueState>((ref) {
  return SyncQueueNotifier(ref.watch(laundryRepositoryProvider));
});

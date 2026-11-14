import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/data/laundry_repository.dart';
import '../orders/data/models.dart';
import '../orders/orders_providers.dart';

class DeliveriesState {
  final bool isLoading;
  final List<DeliveryModel> items;
  final String typeFilter;
  final String statusFilter;
  final String? errorMessage;

  const DeliveriesState({
    this.isLoading = false,
    this.items = const [],
    this.typeFilter = 'all',
    this.statusFilter = 'all',
    this.errorMessage,
  });

  int get pickupCount => items.where((i) => i.isPickup && !i.isCompleted).length;
  int get deliveryCount => items.where((i) => i.isDelivery && !i.isCompleted).length;
  int get completedCount => items.where((i) => i.isCompleted).length;
  int get activeCount => items.where((i) => !i.isCompleted).length;

  DeliveriesState copyWith({
    bool? isLoading,
    List<DeliveryModel>? items,
    String? typeFilter,
    String? statusFilter,
    String? errorMessage,
  }) =>
      DeliveriesState(
        isLoading: isLoading ?? this.isLoading,
        items: items ?? this.items,
        typeFilter: typeFilter ?? this.typeFilter,
        statusFilter: statusFilter ?? this.statusFilter,
        errorMessage: errorMessage,
      );
}

class DeliveriesNotifier extends StateNotifier<DeliveriesState> {
  final LaundryRepository _repo;

  DeliveriesNotifier(this._repo) : super(const DeliveriesState()) {
    loadDeliveries();
  }

  Future<void> loadDeliveries() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repo.fetchDeliveries(
        type: state.typeFilter == 'all' ? null : state.typeFilter,
        status: state.statusFilter == 'all' ? null : state.statusFilter,
      );
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setTypeFilter(String type) {
    state = state.copyWith(typeFilter: type);
    loadDeliveries();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
    loadDeliveries();
  }

  Future<bool> updateStatus(int id, String status, {String? notes, String? proofPhoto}) async {
    try {
      await _repo.updateDeliveryStatus(id, status, notes: notes, proofPhoto: proofPhoto);
      await loadDeliveries();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final deliveriesProvider =
    StateNotifierProvider<DeliveriesNotifier, DeliveriesState>((ref) {
  return DeliveriesNotifier(ref.watch(laundryRepositoryProvider));
});

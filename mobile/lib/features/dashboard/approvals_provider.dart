import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/data/laundry_repository.dart';
import '../orders/data/models.dart';
import '../orders/orders_providers.dart';

class ApprovalsState {
  final bool isLoading;
  final List<ApprovalModel> items;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final String statusFilter;
  final String categoryFilter;
  final String? errorMessage;

  const ApprovalsState({
    this.isLoading = false,
    this.items = const [],
    this.pendingCount = 0,
    this.approvedCount = 0,
    this.rejectedCount = 0,
    this.statusFilter = 'all',
    this.categoryFilter = 'all',
    this.errorMessage,
  });

  ApprovalsState copyWith({
    bool? isLoading,
    List<ApprovalModel>? items,
    int? pendingCount,
    int? approvedCount,
    int? rejectedCount,
    String? statusFilter,
    String? categoryFilter,
    String? errorMessage,
  }) =>
      ApprovalsState(
        isLoading: isLoading ?? this.isLoading,
        items: items ?? this.items,
        pendingCount: pendingCount ?? this.pendingCount,
        approvedCount: approvedCount ?? this.approvedCount,
        rejectedCount: rejectedCount ?? this.rejectedCount,
        statusFilter: statusFilter ?? this.statusFilter,
        categoryFilter: categoryFilter ?? this.categoryFilter,
        errorMessage: errorMessage,
      );
}

class ApprovalsNotifier extends StateNotifier<ApprovalsState> {
  final LaundryRepository _repo;

  ApprovalsNotifier(this._repo) : super(const ApprovalsState()) {
    loadApprovals();
  }

  Future<void> loadApprovals() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _repo.fetchApprovals(
        status: state.statusFilter,
        type: state.categoryFilter,
      );
      final items = res['items'] as List<ApprovalModel>? ?? [];
      final meta = res['meta'] as Map<String, dynamic>? ?? {};

      state = state.copyWith(
        isLoading: false,
        items: items,
        pendingCount: (meta['pending_count'] ?? items.where((i) => i.isPending).length).toInt(),
        approvedCount: (meta['approved_count'] ?? items.where((i) => i.isApproved).length).toInt(),
        rejectedCount: (meta['rejected_count'] ?? items.where((i) => i.isRejected).length).toInt(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
    loadApprovals();
  }

  void setCategoryFilter(String category) {
    state = state.copyWith(categoryFilter: category);
    loadApprovals();
  }

  Future<bool> approve(int id, {String? notes, int? refundAmount}) async {
    try {
      await _repo.approveRequest(id, notes: notes, refundAmount: refundAmount);
      await loadApprovals();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> reject(int id, {required String reason}) async {
    try {
      await _repo.rejectRequest(id, reason: reason);
      await loadApprovals();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final approvalsProvider =
    StateNotifierProvider<ApprovalsNotifier, ApprovalsState>((ref) {
  return ApprovalsNotifier(ref.watch(laundryRepositoryProvider));
});

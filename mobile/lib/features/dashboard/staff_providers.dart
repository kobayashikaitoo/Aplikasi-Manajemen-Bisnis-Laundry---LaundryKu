import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class StaffModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final int? branchId;
  final bool isActive;
  final String? createdAt;

  const StaffModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.branchId,
    required this.isActive,
    this.createdAt,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) => StaffModel(
        id: (json['id'] ?? 0).toInt(),
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        role: json['role'] ?? 'pegawai',
        branchId: json['branch_id'],
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'],
      );
}

class StaffNotifier extends StateNotifier<AsyncValue<List<StaffModel>>> {
  final ApiClient _api;

  StaffNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchStaff();
  }

  Future<void> fetchStaff() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.get('/staff');
      final list = (res as List).map((e) => StaffModel.fromJson(e)).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> createStaff({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      await _api.post('/staff', data: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      await fetchStaff();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleStatus(int id) async {
    try {
      await _api.patch('/staff/$id/toggle-status');
      await fetchStaff();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final staffProvider =
    StateNotifierProvider<StaffNotifier, AsyncValue<List<StaffModel>>>((ref) {
  final api = ref.watch(apiClientProvider);
  return StaffNotifier(api);
});

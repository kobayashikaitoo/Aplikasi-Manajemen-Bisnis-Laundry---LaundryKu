import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final int? branchId;
  final int? customerId;
  final int pointBalance;
  final String? address;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.branchId,
    this.customerId,
    this.pointBalance = 0,
    this.address,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'pegawai',
      branchId: json['branch_id'],
      customerId: json['customer_id'],
      pointBalance: json['point_balance'] ?? 0,
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'branch_id': branchId,
    'customer_id': customerId,
    'point_balance': pointBalance,
    'address': address,
  };

  bool get isOwner => role.toLowerCase() == 'pemilik';
  bool get isStaff => role.toLowerCase() == 'pegawai';
  bool get isCustomer => role.toLowerCase() == 'pelanggan';
  bool get isCourier => role.toLowerCase() == 'kurir';
}

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    final token = await TokenStorage.getToken();
    final userJson = await TokenStorage.getUserData();

    if (token != null && userJson != null) {
      try {
        final user = UserModel.fromJson(jsonDecode(userJson));
        state = state.copyWith(user: user, isLoading: false);
        // Refresh from server in background
        _refreshUser();
        return;
      } catch (_) {}
    }

    state = state.copyWith(isLoading: false);
  }

  Future<void> _refreshUser() async {
    try {
      final res = await _api.get('/auth/me');
      final user = UserModel.fromJson(res);
      await TokenStorage.saveUserData(jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = res['token'];
      final user = UserModel.fromJson(res['user']);

      await TokenStorage.saveToken(token);
      await TokenStorage.saveUserData(jsonEncode(user.toJson()));

      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal terhubung ke server');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String role = 'pelanggan',
    String? phone,
    String? address,
    bool autoLogin = true,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'pelanggan',
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
      });

      if (autoLogin && res is Map && res['token'] != null) {
        final token = res['token'];
        final user = UserModel.fromJson(res['user']);
        await TokenStorage.saveToken(token);
        await TokenStorage.saveUserData(jsonEncode(user.toJson()));
        state = state.copyWith(user: user, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Gagal terhubung ke server');
      return false;
    }
  }

  Future<String?> resetPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.post('/auth/forgot-password', data: {
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
      state = state.copyWith(isLoading: false);
      if (res is Map && res['message'] != null) {
        return res['message'].toString();
      }
      return 'Kata sandi berhasil diatur ulang.';
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Gagal terhubung ke server');
      return null;
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? phone,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.put('/auth/profile', data: {
        'name': name,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
      });
      final user = UserModel.fromJson(res['user']);
      await TokenStorage.saveUserData(jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Gagal memperbarui profil');
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Gagal mengubah kata sandi');
      return false;
    }
  }

  Future<bool> updateAddress(String address) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.put('/auth/address', data: {'address': address});
      if (state.user != null) {
        final updatedUser = UserModel(
          id: state.user!.id,
          name: state.user!.name,
          email: state.user!.email,
          phone: state.user!.phone,
          role: state.user!.role,
          branchId: state.user!.branchId,
          customerId: state.user!.customerId,
          pointBalance: state.user!.pointBalance,
          address: res['address'] ?? address,
        );
        await TokenStorage.saveUserData(jsonEncode(updatedUser.toJson()));
        state = state.copyWith(user: updatedUser, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Gagal memperbarui alamat');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.delete('/auth/account');
      await logout();
      return true;
    } catch (_) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Gagal menonaktifkan akun');
      return false;
    }
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthNotifier(api);
});

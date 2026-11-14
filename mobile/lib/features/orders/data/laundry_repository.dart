import '../../../core/api/api_client.dart';
import 'models.dart';

/// Single entry point for every /api/v1 call used by the app.
class LaundryRepository {
  final ApiClient _api;

  LaundryRepository(this._api);

  // ---- Services ----
  Future<List<ServiceModel>> fetchServices() async {
    final res = await _api.get('/services');
    return (res as List).map((e) => ServiceModel.fromJson(e)).toList();
  }

  Future<ServiceModel> createService(Map<String, dynamic> payload) async {
    final res = await _api.post('/services', data: payload);
    return ServiceModel.fromJson(res);
  }

  Future<ServiceModel> updateService(int id, Map<String, dynamic> payload) async {
    final res = await _api.patch('/services/$id', data: payload);
    return ServiceModel.fromJson(res);
  }

  // ---- Customers ----
  Future<List<CustomerModel>> fetchCustomers() async {
    final res = await _api.get('/customers');
    return (res as List).map((e) => CustomerModel.fromJson(e)).toList();
  }

  Future<PointsModel> fetchPoints(int customerId) async {
    final res = await _api.get('/customers/$customerId/points');
    return PointsModel.fromJson(res);
  }

  Future<void> redeemPoints({
    required int customerId,
    required int points,
    String? description,
  }) async {
    final payload = <String, dynamic>{'points': points};
    if (description != null) payload['description'] = description;
    await _api.post('/customers/$customerId/redeem-points', data: payload);
  }

  // ---- Orders ----
  Future<List<OrderModel>> fetchOrders({String? status, String? search}) async {
    final res = await _api.get('/orders', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'per_page': 50,
    });
    return (res as List).map((e) => OrderModel.fromJson(e)).toList();
  }

  Future<OrderModel> fetchOrderDetail(int id) async {
    final res = await _api.get('/orders/$id');
    return OrderModel.fromJson(res);
  }

  /// Find order by scanned barcode / order number, returns null when absent.
  Future<OrderModel?> findByBarcode(String code) async {
    final res = await _api.get('/orders', queryParameters: {'search': code});
    final list = (res as List).map((e) => OrderModel.fromJson(e)).toList();
    if (list.isEmpty) return null;
    return list.firstWhere(
      (o) => o.barcode == code || o.orderNo == code,
      orElse: () => list.first,
    );
  }

  Future<OrderModel> createOrder({
    required int customerId,
    required List<Map<String, dynamic>> items,
    int discountAmount = 0,
    int pointsRedeemed = 0,
    String? notes,
    required String idempotencyKey,
  }) async {
    final res = await _api.post('/orders', data: {
      'customer_id': customerId,
      'items': items,
      'discount_amount': discountAmount,
      if (pointsRedeemed > 0) 'points_redeemed': pointsRedeemed,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }, headers: {'Idempotency-Key': idempotencyKey});
    return OrderModel.fromJson(res);
  }

  Future<void> uploadPhoto(int orderId, String base64DataUri,
      {String photoType = 'initial'}) async {
    await _api.post('/orders/$orderId/photos',
        data: {'photo': base64DataUri, 'photo_type': photoType});
  }

  Future<OrderModel> updateStatus(int orderId, String status,
      {String? reason}) async {
    final res = await _api.patch('/orders/$orderId/status', data: {
      'status': status,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return OrderModel.fromJson(res);
  }

  // ---- Payments ----
  Future<void> recordPayment({
    required int orderId,
    required int amount,
    required String method,
    required String idempotencyKey,
  }) async {
    await _api.post('/orders/$orderId/payments', data: {
      'amount': amount,
      'payment_method': method,
    }, headers: {'Idempotency-Key': idempotencyKey});
  }

  // ---- Notifications ----
  Future<List<NotificationModel>> fetchNotifications() async {
    final res = await _api.get('/notifications');
    return (res as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<void> markNotificationRead(int id) async {
    await _api.patch('/notifications/$id/read');
  }

  // ---- Owner: dashboard, cashflow, audit, demo-queries ----
  Future<DashboardModel> fetchDashboard() async {
    final res = await _api.get('/reports/dashboard');
    return DashboardModel.fromJson(res);
  }

  Future<Map<String, dynamic>> fetchDemoQueries() async {
    final res = await _api.get('/reports/demo-queries');
    if (res is Map<String, dynamic>) {
      return res;
    }
    return {};
  }

  Future<CashflowModel> fetchCashflow() async {
    final res = await _api.get('/reports/cashflow');
    return CashflowModel.fromJson(res);
  }

  Future<void> recordExpense({
    required int amount,
    required String category,
    required String description,
  }) async {
    await _api.post('/cash-transactions',
        data: {'amount': amount, 'category': category, 'description': description});
  }

  Future<List<AuditLogModel>> fetchAuditLogs() async {
    final res = await _api.get('/audit-logs');
    return (res as List).map((e) => AuditLogModel.fromJson(e)).toList();
  }

  // ---- Claims ----
  /// Mengambil klaim yang ada untuk sebuah order (null jika belum ada klaim).
  Future<ClaimModel?> fetchClaim(int orderId) async {
    final res = await _api.get('/orders/$orderId/claims');
    if (res == null) return null;
    if (res is Map<String, dynamic>) {
      if (res['data'] == null && !res.containsKey('claim_type')) return null;
      final map = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      if (map['id'] == null || map['id'] == 0) return null;
      return ClaimModel.fromJson(map);
    }
    return null;
  }

  /// Mengajukan klaim baru untuk order pelanggan.
  Future<ClaimModel> submitClaim({
    required int orderId,
    required String claimType,
    required String description,
    List<String>? photoBase64List,
  }) async {
    final res = await _api.post('/orders/$orderId/claims', data: {
      'claim_type': claimType,
      'description': description,
      if (photoBase64List != null && photoBase64List.isNotEmpty)
        'photos': photoBase64List,
    });
    if (res == null || res is! Map<String, dynamic>) {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Gagal menyimpan klaim. Silakan coba lagi.',
        statusCode: 500,
      );
    }
    return ClaimModel.fromJson(res);
  }

  // ---- Deliveries / Kurir ----
  Future<List<DeliveryModel>> fetchDeliveries({String? type, String? status}) async {
    final query = <String, dynamic>{};
    if (type != null && type.isNotEmpty) query['type'] = type;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final res = await _api.get('/deliveries', queryParameters: query);
    if (res is List) {
      return res.map((e) => DeliveryModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<DeliveryModel> updateDeliveryStatus(int id, String status, {String? notes, String? proofPhoto}) async {
    final res = await _api.patch('/deliveries/$id/status', data: {
      'status': status,
      if (notes != null) 'notes': notes,
      if (proofPhoto != null) 'proof_photo': proofPhoto,
    });
    return DeliveryModel.fromJson(res as Map<String, dynamic>);
  }

  Future<DeliveryModel> createDelivery({
    required int orderId,
    required String type,
    int? courierUserId,
    int fee = 0,
  }) async {
    final res = await _api.post('/deliveries', data: {
      'order_id': orderId,
      'type': type,
      if (courierUserId != null) 'courier_user_id': courierUserId,
      'fee': fee,
    });
    return DeliveryModel.fromJson(res as Map<String, dynamic>);
  }

  // ---- Approvals (Persetujuan Owner) ----
  Future<Map<String, dynamic>> fetchApprovals({String? status, String? type}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (type != null && type.isNotEmpty) query['type'] = type;

    final res = await _api.getRaw('/approvals', queryParameters: query);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final list = (data['data'] as List? ?? [])
          .map((e) => ApprovalModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      return {
        'items': list,
        'meta': meta,
      };
    }
    return {'items': <ApprovalModel>[], 'meta': {}};
  }

  Future<void> approveRequest(int id, {String? notes, int? refundAmount}) async {
    await _api.post('/approvals/$id/approve', data: {
      if (notes != null) 'notes': notes,
      if (refundAmount != null) 'refund_amount': refundAmount,
    });
  }

  Future<void> rejectRequest(int id, {required String reason}) async {
    await _api.post('/approvals/$id/reject', data: {
      'reason': reason,
    });
  }

  // ---- Sync (Antrean Sinkronisasi Kasir) ----
  Future<Map<String, dynamic>> fetchSyncStatus() async {
    final res = await _api.getRaw('/sync/status');
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return {'status': 'online', 'message': 'OK'};
  }

  Future<Map<String, dynamic>> batchSync(List<Map<String, dynamic>> items) async {
    final res = await _api.post('/sync/batch', data: {'items': items});
    return res is Map<String, dynamic> ? res : {};
  }
}

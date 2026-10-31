// Data models mirroring the /api/v1 JSON contract (backend Laravel).
// All money values are integer rupiah — never double.

class ServiceModel {
  final int id;
  final String name;
  final String unit;
  final int price;
  final int estimateDurationHours;
  final double minOrder;
  final bool isActive;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.estimateDurationHours,
    required this.minOrder,
    required this.isActive,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: json['id'],
        name: json['name'] ?? '',
        unit: json['unit'] ?? 'kg',
        price: (json['price'] ?? 0).toInt(),
        estimateDurationHours: (json['estimate_duration_hours'] ?? 0).toInt(),
        minOrder: (json['min_order'] ?? 1).toDouble(),
        isActive: json['is_active'] ?? true,
      );
}

class CustomerModel {
  final int id;
  final String name;
  final String phone;
  final int pointBalance;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.pointBalance,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'],
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        pointBalance: (json['point_balance'] ?? 0).toInt(),
      );
}

class OrderItemModel {
  final int id;
  final String serviceNameSnap;
  final String unitSnap;
  final int unitPrice;
  final double quantity;
  final int subtotal;

  const OrderItemModel({
    required this.id,
    required this.serviceNameSnap,
    required this.unitSnap,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        id: json['id'] ?? 0,
        serviceNameSnap: json['service_name_snap'] ?? '',
        unitSnap: json['unit_snap'] ?? '',
        unitPrice: (json['unit_price'] ?? 0).toInt(),
        quantity: (json['quantity'] ?? 0).toDouble(),
        subtotal: (json['subtotal'] ?? 0).toInt(),
      );

  String get quantityLabel =>
      unitSnap == 'kg' ? '${quantity.toStringAsFixed(1)} kg' : '${quantity.toInt()} $unitSnap';
}

class StatusLogModel {
  final int id;
  final String? fromStatus;
  final String toStatus;
  final String? changedByName;
  final String? reason;
  final String? createdAt;

  const StatusLogModel({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.changedByName,
    this.reason,
    this.createdAt,
  });

  factory StatusLogModel.fromJson(Map<String, dynamic> json) => StatusLogModel(
        id: json['id'] ?? 0,
        fromStatus: json['from_status'],
        toStatus: json['to_status'] ?? '',
        changedByName: json['changed_by']?['name'],
        reason: json['reason'],
        createdAt: json['created_at'],
      );
}

class OrderPhotoModel {
  final int id;
  final String photoPath;
  final String photoType;

  const OrderPhotoModel({
    required this.id,
    required this.photoPath,
    required this.photoType,
  });

  factory OrderPhotoModel.fromJson(Map<String, dynamic> json) =>
      OrderPhotoModel(
        id: json['id'] ?? 0,
        photoPath: json['photo_path'] ?? '',
        photoType: json['photo_type'] ?? 'initial',
      );
}

class PaymentModel {
  final int id;
  final int amount;
  final String paymentMethod;
  final String? createdAt;

  const PaymentModel({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'] ?? 0,
        amount: (json['amount'] ?? 0).toInt(),
        paymentMethod: json['payment_method'] ?? 'cash',
        createdAt: json['created_at'],
      );
}

class OrderModel {
  final int id;
  final String orderNo;
  final String barcode;
  final String status;
  final int subtotal;
  final int discountAmount;
  final int totalAmount;
  final String? notes;
  final String? dueAt;
  final String? completedAt;
  final String? createdAt;
  final CustomerModel? customer;
  final List<OrderItemModel> items;
  final List<StatusLogModel> statusLogs;
  final List<OrderPhotoModel> photos;
  final List<PaymentModel> payments;
  final List<ClaimModel> claims;

  const OrderModel({
    required this.id,
    required this.orderNo,
    required this.barcode,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    this.notes,
    this.dueAt,
    this.completedAt,
    this.createdAt,
    this.customer,
    this.items = const [],
    this.statusLogs = const [],
    this.photos = const [],
    this.payments = const [],
    this.claims = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'],
        orderNo: json['order_no'] ?? '',
        barcode: json['barcode'] ?? json['order_no'] ?? '',
        status: json['status'] ?? 'Diterima',
        subtotal: (json['subtotal'] ?? 0).toInt(),
        discountAmount: (json['discount_amount'] ?? 0).toInt(),
        totalAmount: (json['total_amount'] ?? 0).toInt(),
        notes: json['notes'],
        dueAt: json['due_at'],
        completedAt: json['completed_at'],
        createdAt: json['created_at'],
        customer: json['customer'] != null
            ? CustomerModel.fromJson(json['customer'])
            : null,
        items: ((json['items'] ?? []) as List)
            .map((e) => OrderItemModel.fromJson(e))
            .toList(),
        statusLogs: ((json['status_logs'] ?? []) as List)
            .map((e) => StatusLogModel.fromJson(e))
            .toList(),
        photos: ((json['photos'] ?? []) as List)
            .map((e) => OrderPhotoModel.fromJson(e))
            .toList(),
        payments: ((json['payments'] ?? []) as List)
            .map((e) => PaymentModel.fromJson(e))
            .toList(),
        claims: ((json['claims'] ?? []) as List)
            .map((e) => ClaimModel.fromJson(e))
            .toList(),
      );

  int get totalPaid => payments.fold(0, (sum, p) => sum + p.amount);
  int get remainingBalance => (totalAmount - totalPaid).clamp(0, totalAmount);
  bool get hasInitialPhoto =>
      photos.any((p) => p.photoType == 'initial');
  ClaimModel? get activeClaim => claims.isNotEmpty ? claims.last : null;
  bool get hasClaim => claims.isNotEmpty;
  bool get isClosed =>
      status == 'Selesai' || status == 'Dibatalkan' || status == 'Tidak Diambil';
}

class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final int? orderId;
  final String? createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.orderId,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'],
        type: json['type'] ?? 'info',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        isRead: json['is_read'] ?? false,
        orderId: json['order_id'],
        createdAt: json['created_at'],
      );
}

class CashTransactionModel {
  final int id;
  final String transactionType;
  final String category;
  final int amount;
  final String? description;
  final String? createdAt;

  const CashTransactionModel({
    required this.id,
    required this.transactionType,
    required this.category,
    required this.amount,
    this.description,
    this.createdAt,
  });

  factory CashTransactionModel.fromJson(Map<String, dynamic> json) =>
      CashTransactionModel(
        id: json['id'] ?? 0,
        transactionType: json['transaction_type'] ?? 'in',
        category: json['category'] ?? '',
        amount: (json['amount'] ?? 0).toInt(),
        description: json['description'],
        createdAt: json['created_at'],
      );
}

class AuditLogModel {
  final int id;
  final String action;
  final String? entityType;
  final String? entityId;
  final String? userName;
  final Map<String, dynamic>? newValues;
  final String? createdAt;

  const AuditLogModel({
    required this.id,
    required this.action,
    this.entityType,
    this.entityId,
    this.userName,
    this.newValues,
    this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) => AuditLogModel(
        id: json['id'] ?? 0,
        action: json['action'] ?? '',
        entityType: json['entity_type'],
        entityId: json['entity_id'],
        userName: json['user']?['name'],
        newValues: json['new_values'] is Map
            ? Map<String, dynamic>.from(json['new_values'])
            : null,
        createdAt: json['created_at'],
      );
}

class LoyaltyTransactionModel {
  final int id;
  final String type;
  final int points;
  final int balanceAfter;
  final String? description;
  final String? createdAt;

  const LoyaltyTransactionModel({
    required this.id,
    required this.type,
    required this.points,
    required this.balanceAfter,
    this.description,
    this.createdAt,
  });

  factory LoyaltyTransactionModel.fromJson(Map<String, dynamic> json) =>
      LoyaltyTransactionModel(
        id: json['id'] ?? 0,
        type: json['type'] ?? 'earn',
        points: (json['points'] ?? 0).toInt(),
        balanceAfter: (json['balance_after'] ?? 0).toInt(),
        description: json['description'],
        createdAt: json['created_at'],
      );
}

class DashboardModel {
  final int omzetToday;
  final int orderCountToday;
  final int cashInToday;
  final int cashOutToday;
  final int activeOrdersCount;
  final int currentBalance;
  final Map<String, int> statusCounts;
  final List<OrderModel> nearDueOrders;

  const DashboardModel({
    required this.omzetToday,
    required this.orderCountToday,
    required this.cashInToday,
    required this.cashOutToday,
    required this.activeOrdersCount,
    required this.currentBalance,
    required this.statusCounts,
    required this.nearDueOrders,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>? ?? {};
    final statusCounts = <String, int>{};
    (json['status_counts'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => statusCounts[k] = (v as num).toInt());
    return DashboardModel(
      omzetToday: (today['omzet'] ?? 0).toInt(),
      orderCountToday: (today['order_count'] ?? 0).toInt(),
      cashInToday: (today['cash_in'] ?? 0).toInt(),
      cashOutToday: (today['cash_out'] ?? 0).toInt(),
      activeOrdersCount: (json['active_orders_count'] ?? 0).toInt(),
      currentBalance: (json['current_balance'] ?? 0).toInt(),
      statusCounts: statusCounts,
      nearDueOrders: ((json['near_due_orders'] ?? []) as List)
          .map((e) => OrderModel.fromJson(e))
          .toList(),
    );
  }
}

class CashflowModel {
  final int totalIn;
  final int totalOut;
  final int net;
  final List<CashTransactionModel> transactions;

  const CashflowModel({
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.transactions,
  });

  factory CashflowModel.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return CashflowModel(
      totalIn: (summary['total_in'] ?? 0).toInt(),
      totalOut: (summary['total_out'] ?? 0).toInt(),
      net: (summary['net'] ?? 0).toInt(),
      transactions: ((json['transactions'] ?? []) as List)
          .map((e) => CashTransactionModel.fromJson(e))
          .toList(),
    );
  }
}

class ClaimModel {
  final int id;
  final int orderId;
  final String claimType;
  final String description;
  final String status;
  final String? resolution;
  final int refundAmount;
  final String? createdAt;
  final List<OrderPhotoModel> photos;

  const ClaimModel({
    required this.id,
    required this.orderId,
    required this.claimType,
    required this.description,
    required this.status,
    this.resolution,
    required this.refundAmount,
    this.createdAt,
    this.photos = const [],
  });

  factory ClaimModel.fromJson(Map<String, dynamic> json) => ClaimModel(
        id: json['id'] ?? 0,
        orderId: (json['order_id'] ?? 0).toInt(),
        claimType: json['claim_type'] ?? '',
        description: json['description'] ?? '',
        status: json['status'] ?? 'Diajukan',
        resolution: json['resolution'],
        refundAmount: (json['refund_amount'] ?? 0).toInt(),
        createdAt: json['created_at'],
        photos: ((json['photos'] ?? []) as List)
            .map((e) => OrderPhotoModel.fromJson(e))
            .toList(),
      );
}

class PointsModel {
  final int customerId;
  final String customerName;
  final int pointBalance;
  final List<LoyaltyTransactionModel> transactions;

  const PointsModel({
    required this.customerId,
    required this.customerName,
    required this.pointBalance,
    required this.transactions,
  });

  factory PointsModel.fromJson(Map<String, dynamic> json) => PointsModel(
        customerId: (json['customer_id'] ?? 0).toInt(),
        customerName: json['customer_name'] ?? '',
        pointBalance: (json['point_balance'] ?? 0).toInt(),
        transactions: ((json['transactions'] ?? []) as List)
            .map((e) => LoyaltyTransactionModel.fromJson(e))
            .toList(),
      );
}

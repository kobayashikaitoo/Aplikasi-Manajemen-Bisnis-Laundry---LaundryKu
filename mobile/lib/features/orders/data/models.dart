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
  final String? address;
  final int pointBalance;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    required this.pointBalance,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'],
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        address: json['address'] as String?,
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

class DailyOmzetModel {
  final String date;
  final int omzet;

  const DailyOmzetModel({required this.date, required this.omzet});

  factory DailyOmzetModel.fromJson(Map<String, dynamic> json) => DailyOmzetModel(
        date: json['date'] ?? '',
        omzet: (json['omzet'] ?? 0).toInt(),
      );
}

class ServiceRevenueModel {
  final String serviceName;
  final int totalRevenue;
  final double totalQuantity;

  const ServiceRevenueModel({
    required this.serviceName,
    required this.totalRevenue,
    required this.totalQuantity,
  });

  factory ServiceRevenueModel.fromJson(Map<String, dynamic> json) =>
      ServiceRevenueModel(
        serviceName: json['service_name_snap'] ?? 'Layanan',
        totalRevenue: (json['total_revenue'] ?? 0).toInt(),
        totalQuantity: (json['total_quantity'] is num)
            ? (json['total_quantity'] as num).toDouble()
            : (double.tryParse(json['total_quantity']?.toString() ?? '0') ?? 0.0),
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
  final List<DailyOmzetModel> dailyOmzet7d;
  final List<ServiceRevenueModel> revenuePerService;
  final List<CustomerModel> inactiveCustomers;

  const DashboardModel({
    required this.omzetToday,
    required this.orderCountToday,
    required this.cashInToday,
    required this.cashOutToday,
    required this.activeOrdersCount,
    required this.currentBalance,
    required this.statusCounts,
    required this.nearDueOrders,
    this.dailyOmzet7d = const [],
    this.revenuePerService = const [],
    this.inactiveCustomers = const [],
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>? ?? {};
    final statusCounts = <String, int>{};
    (json['status_counts'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => statusCounts[k] = (v as num).toInt());

    final analytics = json['analytics'] as Map<String, dynamic>? ?? {};

    final dailyOmzet7d = ((analytics['q1_daily_omzet_7d'] ?? json['q1_daily_omzet_7d'] ?? []) as List)
        .map((e) => DailyOmzetModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final revenuePerService = ((analytics['q5_revenue_per_service'] ?? json['q5_revenue_per_service'] ?? []) as List)
        .map((e) => ServiceRevenueModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final inactiveCustomers = ((analytics['q4_inactive_customers_30d'] ?? json['q4_inactive_customers_30d'] ?? []) as List)
        .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
        .toList();

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
      dailyOmzet7d: dailyOmzet7d,
      revenuePerService: revenuePerService,
      inactiveCustomers: inactiveCustomers,
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


class DeliveryModel {
  final int id;
  final int orderId;
  final int? courierUserId;
  final String type; // 'pickup' or 'delivery'
  final String status; // 'pending', 'assigned', 'on_the_way', 'completed', 'cancelled'
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final int fee;
  final OrderModel? order;

  const DeliveryModel({
    required this.id,
    required this.orderId,
    this.courierUserId,
    required this.type,
    required this.status,
    this.scheduledAt,
    this.completedAt,
    required this.fee,
    this.order,
  });

  bool get isPickup => type.toLowerCase() == 'pickup';
  bool get isDelivery => type.toLowerCase() == 'delivery';
  bool get isCompleted => status == 'completed';
  bool get isOnTheWay => status == 'on_the_way';
  bool get isPending => status == 'pending';

  factory DeliveryModel.fromJson(Map<String, dynamic> json) => DeliveryModel(
        id: (json['id'] ?? 0).toInt(),
        orderId: (json['order_id'] ?? 0).toInt(),
        courierUserId: json['courier_user_id'] != null
            ? (json['courier_user_id'] as num).toInt()
            : null,
        type: json['type'] ?? 'delivery',
        status: json['status'] ?? 'pending',
        scheduledAt: json['scheduled_at'] != null
            ? DateTime.tryParse(json['scheduled_at'])
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'])
            : null,
        fee: (json['fee'] ?? 0).toInt(),
        order: json['order'] != null ? OrderModel.fromJson(json['order']) : null,
      );
}

class ApprovalModel {
  final int id;
  final String sourceType; // 'claim', 'cancel', 'discount'
  final String title;
  final String categoryLabel;
  final int orderId;
  final String orderNo;
  final String customerName;
  final String requesterName;
  final String description;
  final int amount;
  final String amountLabel;
  final String status; // 'pending', 'approved', 'rejected'
  final String statusRaw;
  final String? notes;
  final String? createdAt;
  final List<String> photos;

  const ApprovalModel({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.categoryLabel,
    required this.orderId,
    required this.orderNo,
    required this.customerName,
    required this.requesterName,
    required this.description,
    required this.amount,
    required this.amountLabel,
    required this.status,
    required this.statusRaw,
    this.notes,
    this.createdAt,
    this.photos = const [],
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory ApprovalModel.fromJson(Map<String, dynamic> json) => ApprovalModel(
        id: (json['id'] ?? 0).toInt(),
        sourceType: json['source_type'] ?? 'claim',
        title: json['title'] ?? '',
        categoryLabel: json['category_label'] ?? 'Persetujuan',
        orderId: (json['order_id'] ?? 0).toInt(),
        orderNo: json['order_no'] ?? '',
        customerName: json['customer_name'] ?? '',
        requesterName: json['requester_name'] ?? '',
        description: json['description'] ?? '',
        amount: (json['amount'] ?? 0).toInt(),
        amountLabel: json['amount_label'] ?? 'Nilai',
        status: json['status'] ?? 'pending',
        statusRaw: json['status_raw'] ?? '',
        notes: json['notes'],
        createdAt: json['created_at'],
        photos: ((json['photos'] ?? []) as List).map((e) => e.toString()).toList(),
      );
}

class SyncQueueItem {
  final String id;
  final String actionType; // 'CREATE_ORDER', 'PAYMENT', 'UPDATE_STATUS', 'UPLOAD_PHOTO'
  final String title;
  final String orderNo;
  final String customerName;
  final int amount;
  final String status; // 'pending', 'synced', 'failed'
  final DateTime queuedAt;
  final DateTime? syncedAt;
  final String? errorMessage;
  final Map<String, dynamic> payload;

  const SyncQueueItem({
    required this.id,
    required this.actionType,
    required this.title,
    required this.orderNo,
    required this.customerName,
    this.amount = 0,
    required this.status,
    required this.queuedAt,
    this.syncedAt,
    this.errorMessage,
    required this.payload,
  });

  bool get isPending => status == 'pending';
  bool get isSynced => status == 'synced';
  bool get isFailed => status == 'failed';

  SyncQueueItem copyWith({
    String? status,
    DateTime? syncedAt,
    String? errorMessage,
  }) =>
      SyncQueueItem(
        id: id,
        actionType: actionType,
        title: title,
        orderNo: orderNo,
        customerName: customerName,
        amount: amount,
        status: status ?? this.status,
        queuedAt: queuedAt,
        syncedAt: syncedAt ?? this.syncedAt,
        errorMessage: errorMessage ?? this.errorMessage,
        payload: payload,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'action_type': actionType,
        'title': title,
        'order_no': orderNo,
        'customer_name': customerName,
        'amount': amount,
        'status': status,
        'queued_at': queuedAt.toIso8601String(),
        'synced_at': syncedAt?.toIso8601String(),
        'error_message': errorMessage,
        'payload': payload,
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'] ?? '',
        actionType: json['action_type'] ?? '',
        title: json['title'] ?? '',
        orderNo: json['order_no'] ?? '',
        customerName: json['customer_name'] ?? '',
        amount: (json['amount'] ?? 0).toInt(),
        status: json['status'] ?? 'pending',
        queuedAt: DateTime.tryParse(json['queued_at'] ?? '') ?? DateTime.now(),
        syncedAt: json['synced_at'] != null ? DateTime.tryParse(json['synced_at']) : null,
        errorMessage: json['error_message'],
        payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : {},
      );
}

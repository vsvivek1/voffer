enum OrderStatus { reserved, fulfilled, cancelled }

OrderStatus orderStatusFromString(String? value) => OrderStatus.values
    .firstWhere((s) => s.name == value, orElse: () => OrderStatus.reserved);

/// A customer's purchase of an offer. Payment happens at the firm, so an
/// order starts as [OrderStatus.reserved] and the firm marks it fulfilled.
class Order {
  const Order({
    required this.id,
    required this.offerId,
    required this.offerTitle,
    required this.firmId,
    required this.firmName,
    required this.customerId,
    required this.customerName,
    required this.quantity,
    required this.unitPrice,
    required this.status,
    required this.code,
    required this.createdAt,
  });

  final String id;
  final String offerId;
  final String offerTitle;
  final String firmId;
  final String firmName;
  final String customerId;
  final String customerName;
  final int quantity;
  final double unitPrice;
  final OrderStatus status;

  /// Short code the customer shows at the firm to redeem the order.
  final String code;
  final DateTime createdAt;

  double get total => unitPrice * quantity;

  Order copyWith({OrderStatus? status}) => Order(
    id: id,
    offerId: offerId,
    offerTitle: offerTitle,
    firmId: firmId,
    firmName: firmName,
    customerId: customerId,
    customerName: customerName,
    quantity: quantity,
    unitPrice: unitPrice,
    status: status ?? this.status,
    code: code,
    createdAt: createdAt,
  );

  factory Order.fromMap(Map<String, dynamic> map) => Order(
    id: map['id'] as String,
    offerId: map['offer_id'] as String,
    offerTitle: (map['offer_title'] ?? '') as String,
    firmId: map['firm_id'] as String,
    firmName: (map['firm_name'] ?? '') as String,
    customerId: map['customer_id'] as String,
    customerName: (map['customer_name'] ?? '') as String,
    quantity: map['quantity'] as int,
    unitPrice: (map['unit_price'] as num).toDouble(),
    status: orderStatusFromString(map['status'] as String?),
    code: map['code'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

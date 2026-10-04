enum OrderStatus { reserved, fulfilled, cancelled }

OrderStatus orderStatusFromString(String? value) => OrderStatus.values
    .firstWhere((s) => s.name == value, orElse: () => OrderStatus.reserved);

const _qrPrefix = 'voffer:order:';

/// The order code inside a scanned QR payload or typed by hand, or null when
/// [text] is not one.
String? parseOrderCode(String text) {
  var code = text.trim();
  if (code.toLowerCase().startsWith(_qrPrefix)) {
    code = code.substring(_qrPrefix.length);
  }
  code = code.trim().toUpperCase();
  return RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(code) ? code : null;
}

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
    this.redeemedAt,
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

  /// When the shop redeemed the order, if it has.
  final DateTime? redeemedAt;

  /// What the order's QR code encodes.
  String get qrPayload => '$_qrPrefix$code';

  double get total => unitPrice * quantity;

  Order copyWith({OrderStatus? status, DateTime? redeemedAt}) => Order(
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
    redeemedAt: redeemedAt ?? this.redeemedAt,
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
    redeemedAt: switch (map['redeemed_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );
}

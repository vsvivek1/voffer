/// A note telling a customer that a shop they follow published an offer.
class Alert {
  const Alert({
    required this.id,
    required this.shopId,
    required this.offerId,
    required this.title,
    required this.body,
    required this.at,
    this.isRead = false,
  });

  final String id;
  final String shopId;
  final String offerId;
  final String title;
  final String body;

  /// When the alert appeared: when the offer went live.
  final DateTime at;
  final bool isRead;

  Alert copyWith({bool? isRead}) => Alert(
    id: id,
    shopId: shopId,
    offerId: offerId,
    title: title,
    body: body,
    at: at,
    isRead: isRead ?? this.isRead,
  );

  factory Alert.fromMap(Map<String, dynamic> map) => Alert(
    id: map['id'] as String,
    shopId: map['shop_id'] as String,
    offerId: map['offer_id'] as String,
    title: map['title'] as String,
    body: map['body'] as String,
    at: DateTime.parse(map['visible_at'] as String),
    isRead: map['read_at'] != null,
  );
}

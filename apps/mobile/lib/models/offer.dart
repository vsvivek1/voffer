class Offer {
  const Offer({
    required this.id,
    required this.firmId,
    required this.firmName,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.expiresAt,
    required this.createdAt,
    DateTime? startsAt,
    this.originalPrice,
    this.imageUrl,
    this.quantityAvailable,
    this.isActive = true,
    this.distanceKm,
    this.shopAddress,
    this.currency = 'INR',
  }) : startsAt = startsAt ?? createdAt;

  final String id;
  final String firmId;
  final String firmName;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;

  /// ISO 4217 code of [price], from the shop's country.
  final String currency;
  final String category;
  final String? imageUrl;

  /// Null means unlimited stock.
  final int? quantityAvailable;
  final DateTime startsAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool isActive;

  /// Distance from the customer, set only on nearby results.
  final double? distanceKm;

  /// The shop's address, set only on nearby results.
  final String? shopAddress;

  bool get isScheduled => DateTime.now().isBefore(startsAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isSoldOut => quantityAvailable != null && quantityAvailable! <= 0;
  bool get isLive => isActive && !isScheduled && !isExpired;
  bool get isBuyable => isLive && !isSoldOut;

  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= price || original == 0) return null;
    return ((1 - price / original) * 100).round();
  }

  Offer copyWith({
    int? quantityAvailable,
    bool? isActive,
    String? firmName,
    double? distanceKm,
    String? shopAddress,
    String? currency,
  }) => Offer(
    id: id,
    firmId: firmId,
    firmName: firmName ?? this.firmName,
    title: title,
    description: description,
    price: price,
    originalPrice: originalPrice,
    category: category,
    imageUrl: imageUrl,
    quantityAvailable: quantityAvailable ?? this.quantityAvailable,
    startsAt: startsAt,
    expiresAt: expiresAt,
    createdAt: createdAt,
    isActive: isActive ?? this.isActive,
    distanceKm: distanceKm ?? this.distanceKm,
    shopAddress: shopAddress ?? this.shopAddress,
    currency: currency ?? this.currency,
  );

  factory Offer.fromMap(Map<String, dynamic> map) => Offer(
    id: map['id'] as String,
    firmId: map['firm_id'] as String,
    firmName:
        (map['firm_name'] ??
                (map['profiles'] as Map<String, dynamic>?)?['display_name'] ??
                '')
            as String,
    title: map['title'] as String,
    description: (map['description'] ?? '') as String,
    price: (map['price'] as num).toDouble(),
    originalPrice: (map['original_price'] as num?)?.toDouble(),
    category: (map['category'] ?? 'Other') as String,
    imageUrl: map['image_url'] as String?,
    quantityAvailable: map['quantity_available'] as int?,
    startsAt: map['starts_at'] == null
        ? null
        : DateTime.parse(map['starts_at'] as String),
    expiresAt: DateTime.parse(map['expires_at'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    isActive: (map['is_active'] ?? true) as bool,
    distanceKm: (map['distance_km'] as num?)?.toDouble(),
    shopAddress: map['shop_address'] as String?,
    currency: (map['currency'] ?? 'INR') as String,
  );
}

/// Fields a firm fills in when publishing a new offer.
class NewOffer {
  const NewOffer({
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.expiresAt,
    this.startsAt,
    this.originalPrice,
    this.imageUrl,
    this.quantityAvailable,
  });

  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final String category;
  final String? imageUrl;
  final int? quantityAvailable;

  /// Null means the offer goes live as soon as it is published.
  final DateTime? startsAt;
  final DateTime expiresAt;

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'price': price,
    'original_price': originalPrice,
    'category': category,
    'image_url': imageUrl,
    'quantity_available': quantityAvailable,
    'starts_at': ?startsAt?.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
}

const offerCategories = [
  'Food & Drink',
  'Fashion',
  'Electronics',
  'Beauty',
  'Services',
  'Groceries',
  'Other',
];

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
    this.originalPrice,
    this.imageUrl,
    this.quantityAvailable,
    this.isActive = true,
  });

  final String id;
  final String firmId;
  final String firmName;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final String category;
  final String? imageUrl;

  /// Null means unlimited stock.
  final int? quantityAvailable;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool isActive;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isSoldOut => quantityAvailable != null && quantityAvailable! <= 0;
  bool get isBuyable => isActive && !isExpired && !isSoldOut;

  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= price || original == 0) return null;
    return ((1 - price / original) * 100).round();
  }

  Offer copyWith({int? quantityAvailable, bool? isActive}) => Offer(
    id: id,
    firmId: firmId,
    firmName: firmName,
    title: title,
    description: description,
    price: price,
    originalPrice: originalPrice,
    category: category,
    imageUrl: imageUrl,
    quantityAvailable: quantityAvailable ?? this.quantityAvailable,
    expiresAt: expiresAt,
    createdAt: createdAt,
    isActive: isActive ?? this.isActive,
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
    expiresAt: DateTime.parse(map['expires_at'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    isActive: (map['is_active'] ?? true) as bool,
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
  final DateTime expiresAt;

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'price': price,
    'original_price': originalPrice,
    'category': category,
    'image_url': imageUrl,
    'quantity_available': quantityAvailable,
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

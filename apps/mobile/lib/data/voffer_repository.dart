import '../models/app_user.dart';
import '../models/offer.dart';
import '../models/order.dart';
import '../models/shop.dart';

class RepositoryException implements Exception {
  RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Everything the app needs from a backend. [MockVofferRepository] and
/// [SupabaseVofferRepository] are the two implementations.
abstract class VofferRepository {
  /// The signed-in user restored from a previous session, if any.
  Future<AppUser?> currentUser();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  });

  Future<void> signOut();

  /// Live offers from every firm, newest first.
  Future<List<Offer>> fetchFeed({String? category, String? query});

  /// Live offers from shops within [radiusKm] of [near], nearest first, with
  /// [Offer.distanceKm] set.
  Future<List<Offer>> fetchNearby({
    required GeoPoint near,
    double radiusKm = 10,
    String? category,
    String? query,
  });

  /// The shop of the firm [shopId], or null if it has not set one up yet.
  Future<Shop?> fetchShop(String shopId);

  /// Creates or updates [firm]'s shop. The shop name also becomes the firm's
  /// display name.
  Future<Shop> saveShop(AppUser firm, ShopDetails details);

  /// Live offers from one shop, newest first.
  Future<List<Offer>> fetchShopOffers(String shopId);

  /// All offers published by [firmId], including expired and paused ones.
  Future<List<Offer>> fetchFirmOffers(String firmId);

  Future<Offer> publishOffer(AppUser firm, NewOffer offer);

  Future<void> setOfferActive(String offerId, bool isActive);

  /// Reserves [quantity] units of an offer for [customer], reducing stock.
  Future<Order> placeOrder(AppUser customer, Offer offer, int quantity);

  Future<List<Order>> fetchCustomerOrders(String customerId);

  Future<List<Order>> fetchFirmOrders(String firmId);

  Future<void> updateOrderStatus(String orderId, OrderStatus status);
}

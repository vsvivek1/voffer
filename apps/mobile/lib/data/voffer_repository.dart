import '../models/app_user.dart';
import '../models/offer.dart';
import '../models/order.dart';

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

  /// Active, unexpired offers from every firm, newest first.
  Future<List<Offer>> fetchFeed({String? category, String? query});

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

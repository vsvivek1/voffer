import 'dart:math';

import '../models/app_user.dart';
import '../models/offer.dart';
import '../models/order.dart';
import 'voffer_repository.dart';

/// In-memory backend seeded with demo firms and offers. Used when no
/// Supabase project is configured, and in tests.
class MockVofferRepository implements VofferRepository {
  MockVofferRepository({DateTime? now}) {
    _seed(now ?? DateTime.now());
  }

  final _users = <String, AppUser>{};
  final _passwords = <String, String>{};
  final _offers = <Offer>[];
  final _orders = <Order>[];
  final _random = Random();
  AppUser? _current;
  int _nextId = 1;

  String _id(String prefix) => '$prefix-${_nextId++}';

  String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  void _seed(DateTime now) {
    final cafe = _addUser('cafe@demo.voffer', 'Bean There Cafe', UserRole.firm);
    final store = _addUser('store@demo.voffer', 'Urban Threads', UserRole.firm);
    _addUser('customer@demo.voffer', 'Demo Customer', UserRole.customer);

    _offers.addAll([
      Offer(
        id: _id('offer'),
        firmId: cafe.id,
        firmName: cafe.displayName,
        title: 'Two cappuccinos for the price of one',
        description:
            'Bring a friend. Valid on any regular-size cappuccino, '
            'dine-in or takeaway.',
        price: 180,
        originalPrice: 360,
        category: 'Food & Drink',
        quantityAvailable: 50,
        expiresAt: now.add(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Offer(
        id: _id('offer'),
        firmId: store.id,
        firmName: store.displayName,
        title: '40% off denim jackets',
        description: 'All sizes of our autumn denim range while stock lasts.',
        price: 1499,
        originalPrice: 2499,
        category: 'Fashion',
        quantityAvailable: 12,
        expiresAt: now.add(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      Offer(
        id: _id('offer'),
        firmId: cafe.id,
        firmName: cafe.displayName,
        title: 'Breakfast combo',
        description:
            'Croissant, fresh juice and a filter coffee, served '
            'until 11am.',
        price: 249,
        originalPrice: 320,
        category: 'Food & Drink',
        expiresAt: now.add(const Duration(days: 14)),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  AppUser _addUser(String email, String name, UserRole role) {
    final user = AppUser(
      id: _id('user'),
      email: email,
      displayName: name,
      role: role,
    );
    _users[email] = user;
    _passwords[email] = 'demo1234';
    return user;
  }

  @override
  Future<AppUser?> currentUser() async => _current;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final user = _users[key];
    if (user == null || _passwords[key] != password) {
      throw RepositoryException('Wrong email or password.');
    }
    return _current = user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw RepositoryException('An account with that email already exists.');
    }
    final user = AppUser(
      id: _id('user'),
      email: key,
      displayName: displayName,
      role: role,
    );
    _users[key] = user;
    _passwords[key] = password;
    return _current = user;
  }

  @override
  Future<void> signOut() async => _current = null;

  @override
  Future<List<Offer>> fetchFeed({String? category, String? query}) async {
    final q = query?.trim().toLowerCase() ?? '';
    final feed = _offers.where((o) {
      if (!o.isActive || o.isExpired) return false;
      if (category != null && o.category != category) return false;
      if (q.isEmpty) return true;
      return o.title.toLowerCase().contains(q) ||
          o.firmName.toLowerCase().contains(q) ||
          o.description.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return feed;
  }

  @override
  Future<List<Offer>> fetchFirmOffers(String firmId) async =>
      _offers.where((o) => o.firmId == firmId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Offer> publishOffer(AppUser firm, NewOffer offer) async {
    if (!firm.isFirm) throw RepositoryException('Only firms can publish.');
    final created = Offer(
      id: _id('offer'),
      firmId: firm.id,
      firmName: firm.displayName,
      title: offer.title,
      description: offer.description,
      price: offer.price,
      originalPrice: offer.originalPrice,
      category: offer.category,
      imageUrl: offer.imageUrl,
      quantityAvailable: offer.quantityAvailable,
      expiresAt: offer.expiresAt,
      createdAt: DateTime.now(),
    );
    _offers.add(created);
    return created;
  }

  @override
  Future<void> setOfferActive(String offerId, bool isActive) async {
    final i = _offers.indexWhere((o) => o.id == offerId);
    if (i >= 0) _offers[i] = _offers[i].copyWith(isActive: isActive);
  }

  @override
  Future<Order> placeOrder(AppUser customer, Offer offer, int quantity) async {
    final i = _offers.indexWhere((o) => o.id == offer.id);
    if (i < 0) throw RepositoryException('This offer no longer exists.');
    final current = _offers[i];
    if (!current.isBuyable) {
      throw RepositoryException('This offer is no longer available.');
    }
    if (quantity < 1) throw RepositoryException('Choose at least one.');
    final stock = current.quantityAvailable;
    if (stock != null) {
      if (stock < quantity) {
        throw RepositoryException('Only $stock left.');
      }
      _offers[i] = current.copyWith(quantityAvailable: stock - quantity);
    }
    final order = Order(
      id: _id('order'),
      offerId: current.id,
      offerTitle: current.title,
      firmId: current.firmId,
      firmName: current.firmName,
      customerId: customer.id,
      customerName: customer.displayName,
      quantity: quantity,
      unitPrice: current.price,
      status: OrderStatus.reserved,
      code: _code(),
      createdAt: DateTime.now(),
    );
    _orders.add(order);
    return order;
  }

  @override
  Future<List<Order>> fetchCustomerOrders(String customerId) async =>
      _orders.where((o) => o.customerId == customerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Order>> fetchFirmOrders(String firmId) async =>
      _orders.where((o) => o.firmId == firmId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i >= 0) _orders[i] = _orders[i].copyWith(status: status);
  }
}

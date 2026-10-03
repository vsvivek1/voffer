import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/offer.dart';
import '../models/order.dart';
import '../models/shop.dart';
import 'voffer_repository.dart';

/// Backend backed by the schema in `supabase/migrations`.
class SupabaseVofferRepository implements VofferRepository {
  SupabaseVofferRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthException catch (e) {
      throw RepositoryException(e.message);
    } on PostgrestException catch (e) {
      throw RepositoryException(e.message);
    }
  }

  Future<AppUser> _loadProfile(User user) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: row['display_name'] as String,
      role: roleFromString(row['role'] as String?),
    );
  }

  @override
  Future<AppUser?> currentUser() => _guard(() async {
    final user = _client.auth.currentUser;
    return user == null ? null : _loadProfile(user);
  });

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final res = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        return _loadProfile(res.user!);
      });

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) => _guard(() async {
    // The handle_new_user trigger creates the profile row from this
    // metadata.
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName, 'role': role.name},
    );
    if (res.session == null) {
      throw RepositoryException(
        'Check your email to confirm your account, then sign in.',
      );
    }
    return _loadProfile(res.user!);
  });

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<List<Offer>> fetchFeed({
    String? category,
    String? query,
  }) => _guard(() async {
    final now = DateTime.now().toUtc().toIso8601String();
    var request = _client
        .from('offers')
        .select()
        .eq('is_active', true)
        .lte('starts_at', now)
        .gt('expires_at', now);
    if (category != null) request = request.eq('category', category);
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      final pattern = '%${q.replaceAll(RegExp(r'[%_,()]'), '')}%';
      request = request.or(
        'title.ilike.$pattern,firm_name.ilike.$pattern,description.ilike.$pattern',
      );
    }
    final rows = await request.order('created_at', ascending: false);
    return rows.map(Offer.fromMap).toList();
  });

  @override
  Future<List<Offer>> fetchNearby({
    required GeoPoint near,
    double radiusKm = 10,
    String? category,
    String? query,
  }) => _guard(() async {
    final List<dynamic> rows = await _client.rpc(
      'offers_nearby',
      params: {
        'p_lat': near.lat,
        'p_lng': near.lng,
        'p_radius_km': radiusKm,
        'p_category': category,
        'p_query': query?.trim(),
      },
    );
    return rows.cast<Map<String, dynamic>>().map(Offer.fromMap).toList();
  });

  @override
  Future<Shop?> fetchShop(String shopId) => _guard(() async {
    final row = await _client
        .from('shops')
        .select('id, name, category, address, phone, hours, lat, lng')
        .eq('id', shopId)
        .maybeSingle();
    return row == null ? null : Shop.fromMap(row);
  });

  @override
  Future<Shop> saveShop(AppUser firm, ShopDetails details) => _guard(() async {
    final row = await _client
        .rpc(
          'save_shop',
          params: {
            'p_name': details.name,
            'p_category': details.category,
            'p_address': details.address,
            'p_phone': details.phone,
            'p_hours': details.hours,
            'p_lat': details.location.lat,
            'p_lng': details.location.lng,
          },
        )
        .single();
    return Shop.fromMap(row);
  });

  @override
  Future<List<Offer>> fetchShopOffers(String shopId) => _guard(() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('offers')
        .select()
        .eq('firm_id', shopId)
        .eq('is_active', true)
        .lte('starts_at', now)
        .gt('expires_at', now)
        .order('created_at', ascending: false);
    return rows.map(Offer.fromMap).toList();
  });

  @override
  Future<List<Offer>> fetchFirmOffers(String firmId) => _guard(() async {
    final rows = await _client
        .from('offers')
        .select()
        .eq('firm_id', firmId)
        .order('created_at', ascending: false);
    return rows.map(Offer.fromMap).toList();
  });

  @override
  Future<Offer> publishOffer(AppUser firm, NewOffer offer) => _guard(() async {
    final row = await _client
        .from('offers')
        .insert({...offer.toMap(), 'firm_id': firm.id})
        .select()
        .single();
    return Offer.fromMap(row);
  });

  @override
  Future<void> setOfferActive(String offerId, bool isActive) => _guard(
    () => _client
        .from('offers')
        .update({'is_active': isActive})
        .eq('id', offerId),
  );

  @override
  Future<Order> placeOrder(AppUser customer, Offer offer, int quantity) =>
      _guard(() async {
        final row = await _client
            .rpc(
              'place_order',
              params: {'p_offer_id': offer.id, 'p_quantity': quantity},
            )
            .single();
        return Order.fromMap(row);
      });

  @override
  Future<List<Order>> fetchCustomerOrders(String customerId) =>
      _guard(() async {
        final rows = await _client
            .from('orders')
            .select()
            .eq('customer_id', customerId)
            .order('created_at', ascending: false);
        return rows.map(Order.fromMap).toList();
      });

  @override
  Future<List<Order>> fetchFirmOrders(String firmId) => _guard(() async {
    final rows = await _client
        .from('orders')
        .select()
        .eq('firm_id', firmId)
        .order('created_at', ascending: false);
    return rows.map(Order.fromMap).toList();
  });

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) => _guard(
    () => _client
        .from('orders')
        .update({'status': status.name})
        .eq('id', orderId),
  );
}

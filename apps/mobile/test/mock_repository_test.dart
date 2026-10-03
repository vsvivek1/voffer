import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/data/voffer_repository.dart';
import 'package:voffer/models/app_user.dart';
import 'package:voffer/models/offer.dart';
import 'package:voffer/models/order.dart';
import 'package:voffer/models/shop.dart';

void main() {
  late MockVofferRepository repo;

  setUp(() => repo = MockVofferRepository());

  test('rejects a wrong password', () {
    expect(
      repo.signIn(email: 'cafe@demo.voffer', password: 'nope'),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('a firm publishes an offer and customers see it in the feed', () async {
    final firm = await repo.signUp(
      email: 'shop@example.com',
      password: 'secret1',
      displayName: 'Corner Shop',
      role: UserRole.firm,
    );
    await repo.saveShop(
      firm,
      const ShopDetails(
        name: 'Corner Shop',
        category: 'Groceries',
        address: 'Market Road, Kochi',
        location: GeoPoint(9.98, 76.28),
      ),
    );
    await repo.publishOffer(
      firm,
      NewOffer(
        title: 'Half-price samosas',
        description: 'Today only',
        price: 10,
        originalPrice: 20,
        category: 'Food & Drink',
        quantityAvailable: 5,
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
      ),
    );

    final feed = await repo.fetchFeed(query: 'samosa');
    expect(feed, hasLength(1));
    expect(feed.single.firmName, 'Corner Shop');
    expect(feed.single.discountPercent, 50);
  });

  test('buying reserves stock and shows on both sides', () async {
    final customer = await repo.signIn(
      email: 'customer@demo.voffer',
      password: 'demo1234',
    );
    final offer = (await repo.fetchFeed()).firstWhere(
      (o) => o.quantityAvailable != null,
    );
    final stock = offer.quantityAvailable!;

    final order = await repo.placeOrder(customer, offer, 2);
    expect(order.status, OrderStatus.reserved);
    expect(order.total, offer.price * 2);
    expect(order.code, hasLength(6));

    final after = (await repo.fetchFirmOffers(offer.firmId))
        .firstWhere((o) => o.id == offer.id);
    expect(after.quantityAvailable, stock - 2);
    expect(await repo.fetchCustomerOrders(customer.id), hasLength(1));
    expect(await repo.fetchFirmOrders(offer.firmId), hasLength(1));

    await repo.updateOrderStatus(order.id, OrderStatus.fulfilled);
    expect(
      (await repo.fetchFirmOrders(offer.firmId)).single.status,
      OrderStatus.fulfilled,
    );
  });

  test('cannot buy more than is in stock', () async {
    final customer = await repo.signIn(
      email: 'customer@demo.voffer',
      password: 'demo1234',
    );
    final offer = (await repo.fetchFeed()).firstWhere(
      (o) => o.quantityAvailable != null,
    );
    expect(
      repo.placeOrder(customer, offer, offer.quantityAvailable! + 1),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('paused offers leave the feed', () async {
    final offer = (await repo.fetchFeed()).first;
    await repo.setOfferActive(offer.id, false);
    expect(
      (await repo.fetchFeed()).map((o) => o.id),
      isNot(contains(offer.id)),
    );
  });
}

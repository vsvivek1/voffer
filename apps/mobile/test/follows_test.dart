import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/data/voffer_repository.dart';
import 'package:voffer/format.dart';
import 'package:voffer/main.dart';
import 'package:voffer/models/app_user.dart';
import 'package:voffer/models/market.dart';
import 'package:voffer/models/offer.dart';
import 'package:voffer/models/shop.dart';
import 'package:voffer/screens/shop/shop_profile_screen.dart';

NewOffer _offer(String title, {DateTime? startsAt}) => NewOffer(
  title: title,
  description: '',
  price: 5,
  category: 'Food & Drink',
  startsAt: startsAt,
  expiresAt: DateTime.now().add(const Duration(days: 1)),
);

Future<AppUser> demoUser(MockVofferRepository repo, String name) =>
    repo.signIn(email: '$name@demo.voffer', password: 'demo1234');

void main() {
  group('follows and alerts', () {
    late MockVofferRepository repo;
    late AppUser customer;
    late AppUser cafe;

    setUp(() async {
      repo = MockVofferRepository();
      customer = await demoUser(repo, 'customer');
      cafe = await demoUser(repo, 'cafe');
    });

    test('followers get an alert when the shop publishes', () async {
      await repo.setFollowing(customer, cafe.id, true);
      expect(await repo.isFollowing(customer, cafe.id), isTrue);
      expect(await repo.followerCount(cafe.id), 1);

      await repo.publishOffer(cafe, _offer('Free cookie'));
      final alerts = await repo.fetchAlerts(customer);
      expect(alerts.single.title, 'Bean There Cafe has a new offer');
      expect(alerts.single.body, 'Free cookie');
      expect(alerts.single.isRead, isFalse);

      await repo.markAlertsRead(customer);
      expect((await repo.fetchAlerts(customer)).single.isRead, isTrue);
    });

    test('a scheduled offer alerts followers when it starts', () async {
      await repo.setFollowing(customer, cafe.id, true);
      await repo.publishOffer(
        cafe,
        _offer(
          'Weekend brunch',
          startsAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      expect(await repo.fetchAlerts(customer), isEmpty);
    });

    test('unfollowing stops alerts', () async {
      await repo.setFollowing(customer, cafe.id, true);
      await repo.setFollowing(customer, cafe.id, false);
      await repo.publishOffer(cafe, _offer('Free cookie'));
      expect(await repo.fetchAlerts(customer), isEmpty);
      expect(await repo.followerCount(cafe.id), 0);
    });

    test('shops cannot follow shops', () async {
      final store = await demoUser(repo, 'store');
      expect(
        repo.setFollowing(store, cafe.id, true),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('India and USA', () {
    tearDown(() => useMiles = false);

    test('prices show in the shop currency', () {
      expect(formatMoney(5, 'USD'), r'$5.00');
      expect(formatMoney(180, 'INR'), '₹180.00');
    });

    test('distances show in miles in the USA', () {
      useMiles = true;
      expect(formatDistance(1.609344), '1.0 mi');
      expect(formatRadius(defaultRadiusKm), '5 mi');
      useMiles = false;
      expect(formatDistance(1.5), '1.5 km');
      expect(formatRadius(defaultRadiusKm), '10 km');
    });

    test('New York offers are in dollars', () async {
      final repo = MockVofferRepository();
      final nearby = await repo.fetchNearby(near: cities['New York']!);
      expect(nearby.single.firmName, 'Hudson Bagel Co.');
      expect(nearby.single.currency, 'USD');
    });

    test('a shop moved to the USA prices in dollars', () async {
      final repo = MockVofferRepository();
      final cafe = await demoUser(repo, 'cafe');
      final shop = await repo.saveShop(
        cafe,
        ShopDetails(
          name: 'Bean There Cafe',
          category: 'Food & Drink',
          address: 'Main St, Seattle',
          location: cities['Seattle']!,
          country: Country.usa,
        ),
      );
      expect(shop.country, Country.usa);
      final offer = await repo.publishOffer(cafe, _offer('Drip coffee'));
      expect(offer.currency, 'USD');
    });

    test('the country is guessed from the map position', () {
      expect(Country.near(cities['Chicago']!.lng), Country.usa);
      expect(Country.near(cities['Kochi']!.lng), Country.india);
    });
  });

  group('screens', () {
    testWidgets('a customer follows a shop from its profile', (tester) async {
      final repo = MockVofferRepository();
      final cafe = await demoUser(repo, 'cafe');
      final state = AppState(repo);
      state.setUser(await demoUser(repo, 'customer'));
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(home: ShopProfileScreen(shopId: cafe.id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('0 followers'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
      expect(find.textContaining('1 follower'), findsOneWidget);
      expect(await repo.isFollowing(state.user!, cafe.id), isTrue);
    });

    testWidgets('new offers from followed shops show in Alerts', (
      tester,
    ) async {
      final repo = MockVofferRepository();
      final customer = await demoUser(repo, 'customer');
      final cafe = await demoUser(repo, 'cafe');
      await repo.setFollowing(customer, cafe.id, true);
      await repo.publishOffer(cafe, _offer('Free cookie'));
      await repo.signOut();

      final state = AppState(repo);
      await state.restore();
      await tester.pumpWidget(VofferApp(state: state));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'customer@demo.voffer',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'demo1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      // The unread badge.
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(find.text('Bean There Cafe has a new offer'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      await tester.tap(find.text('Bean There Cafe has a new offer'));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
    });
  });
}

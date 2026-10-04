import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/data/voffer_repository.dart';
import 'package:voffer/location/location_service.dart';
import 'package:voffer/main.dart';
import 'package:voffer/models/app_user.dart';
import 'package:voffer/models/offer.dart';
import 'package:voffer/models/shop.dart';

const kochi = GeoPoint(9.9312, 76.2673);

NewOffer _offer(String title, {DateTime? startsAt}) => NewOffer(
  title: title,
  description: '',
  price: 50,
  category: 'Food & Drink',
  startsAt: startsAt,
  expiresAt: DateTime.now().add(const Duration(days: 1)),
);

ShopDetails _details(String name, GeoPoint at) => ShopDetails(
  name: name,
  category: 'Food & Drink',
  address: 'Somewhere, Kochi',
  location: at,
);

void main() {
  group('repository', () {
    late MockVofferRepository repo;

    setUp(() => repo = MockVofferRepository());

    Future<AppUser> newFirm(String name) => repo.signUp(
      email: '${name.toLowerCase().replaceAll(' ', '')}@example.com',
      password: 'secret1',
      displayName: name,
      role: UserRole.firm,
    );

    test('distance between Kochi and Delhi is about 2,000 km', () {
      final km = kochi.distanceKmTo(cities['Delhi']!);
      expect(km, closeTo(2070, 40));
    });

    test('a firm needs a shop before it can publish', () async {
      final firm = await newFirm('Tea Stall');
      expect(
        repo.publishOffer(firm, _offer('Chai')),
        throwsA(isA<RepositoryException>()),
      );
      await repo.saveShop(firm, _details('Tea Stall', kochi));
      await repo.publishOffer(firm, _offer('Chai'));
      expect((await repo.fetchShopOffers(firm.id)).single.title, 'Chai');
    });

    test(
      'nearby offers are sorted by distance and limited by radius',
      () async {
        final near = await newFirm('Next Door');
        await repo.saveShop(near, _details('Next Door', kochi));
        await repo.publishOffer(near, _offer('Closest deal'));
        final far = await newFirm('Far Away');
        await repo.saveShop(far, _details('Far Away', cities['Kozhikode']!));
        await repo.publishOffer(far, _offer('Distant deal'));

        final within10 = await repo.fetchNearby(near: kochi);
        expect(within10.first.title, 'Closest deal');
        expect(within10.first.distanceKm, closeTo(0, 0.01));
        expect(within10.map((o) => o.title), isNot(contains('Distant deal')));
        final distances = within10.map((o) => o.distanceKm!).toList();
        expect(distances, orderedEquals([...distances]..sort()));

        final kozhikode = await repo.fetchNearby(
          near: cities['Kozhikode']!,
          radiusKm: 5,
        );
        expect(kozhikode.single.title, 'Distant deal');
      },
    );

    test('scheduled offers stay hidden until they start', () async {
      final firm = await newFirm('Bakery');
      await repo.saveShop(firm, _details('Bakery', kochi));
      await repo.publishOffer(
        firm,
        _offer(
          'Tomorrow only',
          startsAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      expect(
        (await repo.fetchFeed()).map((o) => o.title),
        isNot(contains('Tomorrow only')),
      );
      expect(await repo.fetchNearby(near: kochi), isNot(isEmpty));
      expect(
        (await repo.fetchNearby(near: kochi)).map((o) => o.title),
        isNot(contains('Tomorrow only')),
      );
      final own = await repo.fetchFirmOffers(firm.id);
      expect(own.single.isScheduled, isTrue);
    });

    test('renaming the shop renames the firm and its offers', () async {
      var firm = await newFirm('Old Name');
      await repo.saveShop(firm, _details('Old Name', kochi));
      await repo.publishOffer(firm, _offer('Deal'));
      await repo.saveShop(firm, _details('New Name', kochi));
      firm = (await repo.currentUser())!;
      expect(firm.displayName, 'New Name');
      expect((await repo.fetchShopOffers(firm.id)).single.firmName, 'New Name');
    });

    test('customers cannot have a shop', () async {
      final customer = await repo.signIn(
        email: 'customer@demo.voffer',
        password: 'demo1234',
      );
      expect(
        repo.saveShop(customer, _details('Nope', kochi)),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('screens', () {
    Future<void> start(WidgetTester tester, AppState state) async {
      await state.restore();
      await tester.pumpWidget(VofferApp(state: state));
      await tester.pumpAndSettle();
    }

    Future<void> signIn(WidgetTester tester, String email) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'demo1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
    }

    testWidgets('customer sees nearby offers and opens the shop', (
      tester,
    ) async {
      await start(
        tester,
        AppState(
          MockVofferRepository(),
          location: const FixedLocationService(kochi),
        ),
      );
      await signIn(tester, 'customer@demo.voffer');

      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Near you · 10 km'), findsOneWidget);
      expect(find.textContaining('Bean There Cafe · 4.3 km'), findsWidgets);

      await tester.tap(find.text('Breakfast combo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Panampilly Nagar, Kochi'), findsOneWidget);

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Daily, 8am–10pm'), findsOneWidget);
      expect(find.text('Live offers'), findsOneWidget);
      expect(find.text('Two cappuccinos for the price of one'), findsOneWidget);
    });

    testWidgets('customer without location picks a city', (tester) async {
      await start(tester, AppState(MockVofferRepository()));
      await signIn(tester, 'customer@demo.voffer');

      expect(find.widgetWithText(AppBar, 'Offers'), findsOneWidget);
      expect(
        find.textContaining('Showing offers from everywhere'),
        findsOneWidget,
      );

      await tester.tap(find.text('Choose location').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kochi'));
      await tester.pumpAndSettle();

      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Kochi · 10 km'), findsOneWidget);
      expect(find.text('40% off denim jackets'), findsOneWidget);
    });

    testWidgets('a new firm sets up its shop before publishing', (
      tester,
    ) async {
      await start(
        tester,
        AppState(
          MockVofferRepository(),
          location: const FixedLocationService(kochi),
        ),
      );
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I run a firm'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business name'),
        'Spice Corner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'spice@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Set up your shop'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'),
        'Broadway, Kochi',
      );
      await tester.scrollUntilVisible(
        find.text('Save and continue'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Save and continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Set where your shop is.'), findsOneWidget);

      await tester.tap(find.text("I'm at the shop"));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pinned at 9.93120'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save and continue'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Save and continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Spice Corner'), findsOneWidget);
      expect(find.text('New offer'), findsOneWidget);
    });
  });
}

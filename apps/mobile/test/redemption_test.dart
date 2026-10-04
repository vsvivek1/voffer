import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/data/voffer_repository.dart';
import 'package:voffer/main.dart';
import 'package:voffer/models/app_user.dart';
import 'package:voffer/models/order.dart';
import 'package:voffer/scanning/qr_scanner.dart';

/// Stands in for the camera: tests call [scan] to "show" it a QR code.
class FakeQrScanner extends QrScanner {
  ValueChanged<String>? _onScanned;

  void scan(String text) => _onScanned!(text);

  @override
  bool get available => true;

  @override
  Widget buildView(ValueChanged<String> onScanned) {
    _onScanned = onScanned;
    return const ColoredBox(color: Colors.black);
  }
}

Future<AppUser> demoUser(MockVofferRepository repo, String name) =>
    repo.signIn(email: '$name@demo.voffer', password: 'demo1234');

/// A cafe order placed by the demo customer.
Future<Order> cafeOrder(MockVofferRepository repo) async {
  final customer = await demoUser(repo, 'customer');
  final offer = (await repo.fetchFeed()).firstWhere(
    (o) => o.firmName == 'Bean There Cafe',
  );
  final order = await repo.placeOrder(customer, offer, 2);
  await repo.signOut();
  return order;
}

void main() {
  test('order codes are read from QR payloads and typed text', () {
    expect(parseOrderCode('voffer:order:AB23CD'), 'AB23CD');
    expect(parseOrderCode(' ab23cd '), 'AB23CD');
    expect(parseOrderCode('https://example.com'), isNull);
    expect(parseOrderCode(''), isNull);
  });

  group('repository', () {
    late MockVofferRepository repo;

    setUp(() => repo = MockVofferRepository());

    test('a shop redeems an order once', () async {
      final order = await cafeOrder(repo);
      final cafe = await demoUser(repo, 'cafe');

      final redeemed = await repo.redeemOrder(cafe, order.code.toLowerCase());
      expect(redeemed.status, OrderStatus.fulfilled);
      expect(redeemed.redeemedAt, isNotNull);
      expect(
        repo.redeemOrder(cafe, order.code),
        throwsA(
          isA<RepositoryException>().having(
            (e) => e.message,
            'message',
            contains('already redeemed'),
          ),
        ),
      );
    });

    test('only the shop that sold the order can redeem it', () async {
      final order = await cafeOrder(repo);
      final store = await demoUser(repo, 'store');
      final customer = await demoUser(repo, 'customer');

      expect(
        repo.redeemOrder(store, order.code),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        repo.redeemOrder(customer, order.code),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('screens', () {
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

    testWidgets('a customer sees a QR code for their order', (tester) async {
      final repo = MockVofferRepository();
      final order = await cafeOrder(repo);
      final state = AppState(repo);
      await state.restore();
      await tester.pumpWidget(VofferApp(state: state));
      await tester.pumpAndSettle();
      await signIn(tester, 'customer@demo.voffer');

      await tester.tap(find.text('My orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(order.offerTitle));
      await tester.pumpAndSettle();

      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.semanticsLabel, 'QR code for order ${order.code}');
      expect(find.text(order.code), findsOneWidget);
      expect(find.textContaining('Show this at Bean There Cafe'), findsOne);
    });

    testWidgets('a shop scans a QR code to redeem the order', (tester) async {
      final repo = MockVofferRepository();
      final order = await cafeOrder(repo);
      final scanner = FakeQrScanner();
      final state = AppState(repo, scanner: scanner);
      await state.restore();
      await tester.pumpWidget(VofferApp(state: state));
      await tester.pumpAndSettle();
      await signIn(tester, 'cafe@demo.voffer');

      await tester.tap(find.byTooltip('Redeem an order'));
      await tester.pumpAndSettle();

      scanner.scan('https://example.com');
      await tester.pumpAndSettle();
      expect(find.text('That is not a Voffer order code.'), findsOneWidget);

      scanner.scan(order.qrPayload);
      await tester.pumpAndSettle();
      expect(find.text('Redeemed ${order.code}'), findsOneWidget);
      expect(find.textContaining('Collect'), findsOneWidget);

      // Typing the same code again is refused.
      await tester.enterText(find.byType(TextField), order.code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text('Order ${order.code} was already redeemed.'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('fulfilled'), findsOneWidget);
    });
  });
}

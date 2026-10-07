import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/data/voffer_repository.dart';
import 'package:voffer/main.dart';
import 'package:voffer/models/order.dart';
import 'package:voffer/screens/sign_in_screen.dart';

/// Fails every account deletion, as a server error would.
class FailingDeleteRepository extends MockVofferRepository {
  @override
  Future<void> deleteAccount() async =>
      throw RepositoryException('Server said no.');
}

void main() {
  Future<Order> customerBuysFromCafe(MockVofferRepository repo) async {
    final customer = await repo.signIn(
      email: 'customer@demo.voffer',
      password: 'demo1234',
    );
    final offer = (await repo.fetchFeed()).firstWhere(
      (o) => o.firmName == 'Bean There Cafe',
    );
    return repo.placeOrder(customer, offer, 1);
  }

  test('a deleted customer can no longer sign in and the shop keeps the '
      'order without their name', () async {
    final repo = MockVofferRepository();
    final state = AppState(repo);
    await state.restore();
    final order = await customerBuysFromCafe(repo);
    state.setUser(await repo.currentUser());

    await state.deleteAccount();

    expect(state.user, isNull);
    expect(
      () => repo.signIn(email: 'customer@demo.voffer', password: 'demo1234'),
      throwsA(isA<RepositoryException>()),
    );
    final kept = (await repo.fetchFirmOrders(order.firmId))
        .firstWhere((o) => o.id == order.id);
    expect(kept.customerName, 'Deleted user');
    expect(kept.customerId, isEmpty);
  });

  test('a deleted shop disappears and its open orders are cancelled for the '
      'customer', () async {
    final repo = MockVofferRepository();
    final state = AppState(repo);
    await state.restore();
    final order = await customerBuysFromCafe(repo);
    await repo.signOut();
    state.setUser(
      await repo.signIn(email: 'cafe@demo.voffer', password: 'demo1234'),
    );

    await state.deleteAccount();

    expect(await repo.fetchShop(order.firmId), isNull);
    expect(
      (await repo.fetchFeed()).where((o) => o.firmName == 'Bean There Cafe'),
      isEmpty,
    );
    final kept = (await repo.fetchCustomerOrders(order.customerId))
        .firstWhere((o) => o.id == order.id);
    expect(kept.status, OrderStatus.cancelled);
    expect(kept.firmName, 'Bean There Cafe');
  });

  Future<void> signInAsCustomer(WidgetTester tester) async {
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
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
  }

  testWidgets('deleting the account from the menu returns to sign in', (
    tester,
  ) async {
    final state = AppState(MockVofferRepository());
    await state.restore();
    await tester.pumpWidget(VofferApp(state: state));
    await tester.pumpAndSettle();
    await signInAsCustomer(tester);

    await openDeleteDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.user, isNotNull);

    await openDeleteDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(state.user, isNull);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('a failed deletion shows the error and stays signed in', (
    tester,
  ) async {
    final state = AppState(FailingDeleteRepository());
    await state.restore();
    await tester.pumpWidget(VofferApp(state: state));
    await tester.pumpAndSettle();
    await signInAsCustomer(tester);

    await openDeleteDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Server said no.'), findsOneWidget);
    expect(state.user, isNotNull);
    expect(find.byType(SignInScreen), findsNothing);
  });
}

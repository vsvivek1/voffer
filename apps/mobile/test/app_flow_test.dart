import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/main.dart';

void main() {
  Future<void> signIn(WidgetTester tester, String email) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'demo1234',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('customer signs in, sees the feed and buys an offer', (
    tester,
  ) async {
    final state = AppState(MockVofferRepository());
    await state.restore();
    await tester.pumpWidget(VofferApp(state: state));
    await tester.pumpAndSettle();

    await signIn(tester, 'customer@demo.voffer');
    expect(find.text('40% off denim jackets'), findsOneWidget);

    await tester.ensureVisible(find.text('40% off denim jackets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('40% off denim jackets'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Buy for'));
    await tester.pumpAndSettle();
    expect(find.text('Reserved!'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My orders'));
    await tester.pumpAndSettle();
    expect(find.text('40% off denim jackets'), findsWidgets);
  });

  testWidgets('firm signs in and publishes an offer', (tester) async {
    final state = AppState(MockVofferRepository());
    await state.restore();
    await tester.pumpWidget(VofferApp(state: state));
    await tester.pumpAndSettle();

    await signIn(tester, 'cafe@demo.voffer');
    expect(find.widgetWithText(AppBar, 'Bean There Cafe'), findsOneWidget);

    await tester.tap(find.text('New offer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Free cookie with latte',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Offer price'),
      '150',
    );
    await tester.scrollUntilVisible(
      find.text('Publish offer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publish offer'));
    await tester.pumpAndSettle();

    expect(find.text('Free cookie with latte'), findsOneWidget);
  });
}

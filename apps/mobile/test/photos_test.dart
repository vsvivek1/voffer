import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/data/voffer_repository.dart';
import 'package:voffer/main.dart';
import 'package:voffer/photos/photo_picker.dart';
import 'package:voffer/widgets/voffer_image.dart';

/// A 1×1 transparent PNG.
final pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class FakePhotoPicker implements PhotoPicker {
  int picks = 0;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    picks++;
    return PickedPhoto(pixel, contentType: 'image/png');
  }
}

void main() {
  group('repository', () {
    late MockVofferRepository repo;

    setUp(() => repo = MockVofferRepository());

    test('a firm uploads a photo and gets a viewable URL', () async {
      final firm = await repo.signIn(
        email: 'cafe@demo.voffer',
        password: 'demo1234',
      );
      final url = await repo.uploadPhoto(
        firm,
        PickedPhoto(pixel, contentType: 'image/png'),
      );
      final data = Uri.parse(url).data!;
      expect(data.mimeType, 'image/png');
      expect(data.contentAsBytes(), pixel);
    });

    test('customers cannot upload photos', () async {
      final customer = await repo.signIn(
        email: 'customer@demo.voffer',
        password: 'demo1234',
      );
      expect(
        repo.uploadPhoto(customer, PickedPhoto(pixel)),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('screens', () {
    Future<(AppState, FakePhotoPicker)> signInAsCafe(
      WidgetTester tester,
    ) async {
      final photos = FakePhotoPicker();
      final state = AppState(MockVofferRepository(), photos: photos);
      await state.restore();
      await tester.pumpWidget(VofferApp(state: state));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'cafe@demo.voffer',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'demo1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      return (state, photos);
    }

    testWidgets('a firm publishes an offer with a photo', (tester) async {
      final (state, photos) = await signInAsCafe(tester);
      expect(find.byType(VofferImage), findsNothing);

      await tester.tap(find.text('New offer'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Iced latte',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Offer price'),
        '120',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Choose photo'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Choose photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(photos.picks, 1);
      expect(find.text('Remove'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Publish offer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Publish offer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish offer'));
      await tester.pumpAndSettle();

      final offers = await state.repository.fetchFirmOffers(state.user!.id);
      final latte = offers.firstWhere((o) => o.title == 'Iced latte');
      expect(Uri.parse(latte.imageUrl!).data!.contentAsBytes(), pixel);
      expect(find.byType(VofferImage), findsOneWidget);
    });

    testWidgets('a firm adds a logo to its shop', (tester) async {
      final (state, _) = await signInAsCafe(tester);

      await tester.tap(find.byTooltip('Edit shop'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Take photo'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Take photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save shop'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Save shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save shop'));
      await tester.pumpAndSettle();

      final shop = await state.repository.fetchShop(state.user!.id);
      expect(shop!.logoUrl, startsWith('data:image/png;base64,'));
      expect(find.text('New offer'), findsOneWidget);
    });
  });
}

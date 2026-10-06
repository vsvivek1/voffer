// Renders the Play Store listing graphics and the launcher icons from the app
// itself, running in demo mode. Not part of the normal test run:
//
//   flutter test tool/store_assets_test.dart
//
// Writes store/android/{icon.png, featureGraphic.png, phoneScreenshots/*.png}
// and the legacy launcher PNGs under android/app/src/main/res/mipmap-*.
// Play wants the feature graphic and screenshots without alpha, so then run:
//
//   for f in store/android/featureGraphic.png store/android/phoneScreenshots/*.png; do
//     convert "$f" -background white -alpha remove -alpha off PNG24:"$f"; done
//
// Pushing changes under store/ to main uploads them (play-listing workflow).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/main.dart';
import 'package:voffer/models/app_user.dart';
import 'package:voffer/models/offer.dart';

const brand = Color(0xFFE4572E);
const outDir = 'store/android';

Future<void> loadFonts() async {
  final fonts =
      '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$fonts/$name').readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(read('Roboto-Regular.ttf'))
    ..addFont(read('Roboto-Medium.ttf'))
    ..addFont(read('Roboto-Bold.ttf'));
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('MaterialIcons-Regular.otf'))).load();
}

/// The app's mark: a white offer tag on the brand colour.
class VofferMark extends StatelessWidget {
  const VofferMark({super.key, this.rounded = false});

  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => DecoratedBox(
        decoration: BoxDecoration(
          color: brand,
          borderRadius: BorderRadius.circular(rounded ? c.maxWidth * 0.22 : 0),
        ),
        child: Center(
          child: Icon(
            Icons.local_offer,
            size: c.maxWidth * 0.58,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class FeatureGraphic extends StatelessWidget {
  const FeatureGraphic({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brand,
      padding: const EdgeInsets.symmetric(horizontal: 72),
      child: Row(
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(48),
            ),
            child: const Icon(Icons.local_offer, size: 130, color: brand),
          ),
          const SizedBox(width: 56),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voffer',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 104,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Deals from shops near you.\nReserve, show the QR, save.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 36,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  final boundary = GlobalKey();

  Future<void> setSize(WidgetTester tester, Size px, double dpr) async {
    tester.view.physicalSize = px;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(WidgetTester tester, String path) async {
    await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await render.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
  }

  Future<void> render(
    WidgetTester tester,
    Widget child,
    Size px,
    String path,
  ) async {
    await setSize(tester, px, 1);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(key: boundary, child: child),
      ),
    );
    await capture(tester, path);
  }

  setUpAll(loadFonts);
  // Tests draw elevation as black outlines unless shadows are turned back on,
  // and the flag must be restored before each test body ends.
  void shotTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  shotTest('icon', (tester) async {
    await render(
      tester,
      const VofferMark(),
      const Size(512, 512),
      '$outDir/icon.png',
    );
  });

  shotTest('launcher icons', (tester) async {
    const sizes = {
      'mdpi': 48.0,
      'hdpi': 72.0,
      'xhdpi': 96.0,
      'xxhdpi': 144.0,
      'xxxhdpi': 192.0,
    };
    for (final MapEntry(:key, :value) in sizes.entries) {
      await render(
        tester,
        const VofferMark(rounded: true),
        Size(value, value),
        'android/app/src/main/res/mipmap-$key/ic_launcher.png',
      );
    }
  });

  shotTest('feature graphic', (tester) async {
    await render(
      tester,
      const FeatureGraphic(),
      const Size(1024, 500),
      '$outDir/featureGraphic.png',
    );
  });

  shotTest('phone screenshots', (tester) async {
    // 1080 x 1920 at a typical phone density.
    await setSize(tester, const Size(1080, 1920), 2.625);
    final repo = MockVofferRepository();
    // Followers and fresh offers, so Alerts and the follower note have content.
    Future<AppUser> demo(String name) =>
        repo.signIn(email: '$name@demo.voffer', password: 'demo1234');
    final customer = await demo('customer');
    final cafe = await demo('cafe');
    final store = await demo('store');
    await repo.setFollowing(customer, cafe.id, true);
    await repo.setFollowing(customer, store.id, true);
    final week = DateTime.now().add(const Duration(days: 7));
    await repo.publishOffer(
      store,
      NewOffer(
        title: 'Buy 2 shirts, get 1 free',
        description: 'Mix and match any shirts in store.',
        price: 1798,
        originalPrice: 2697,
        category: 'Fashion',
        expiresAt: week,
      ),
    );
    await repo.publishOffer(
      cafe,
      NewOffer(
        title: 'Free cookie with any latte',
        description: 'Freshly baked every morning.',
        price: 160,
        originalPrice: 220,
        category: 'Food & Drink',
        expiresAt: week,
      ),
    );
    await repo.signOut();
    final state = AppState(repo);
    await state.restore();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VofferApp(state: state),
      ),
    );
    await tester.pumpAndSettle();
    final shots = '$outDir/phoneScreenshots';

    Future<void> signIn(String email) async {
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
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    // Customer: the feed, an offer, the reservation and its QR code.
    await signIn('customer@demo.voffer');
    await capture(tester, '$shots/1_offers.png');

    final offer = find.text('40% off denim jackets');
    await tester.scrollUntilVisible(
      offer,
      200,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(offer);
    await tester.pumpAndSettle();
    await tester.tap(offer);
    await tester.pumpAndSettle();
    await capture(tester, '$shots/2_offer.png');

    await tester.tap(find.textContaining('Buy for'));
    await tester.pumpAndSettle();
    await capture(tester, '$shots/3_reserved.png');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    await capture(tester, '$shots/4_alerts.png');

    // Shop: its offers and the redemption screen.
    await state.signOut();
    await tester.pumpAndSettle();
    await signIn('store@demo.voffer');
    await capture(tester, '$shots/5_shop.png');
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await capture(tester, '$shots/6_orders.png');
  });
}

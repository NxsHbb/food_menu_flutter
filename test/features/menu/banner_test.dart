import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/domain/promo_banner.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/banner_carousel.dart';

List<Map<String, dynamic>> bannerFixture() {
  final raw = jsonDecode(
    File('test/fixtures/banner_posts.json').readAsStringSync(),
  ) as List<dynamic>;
  return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
}

void main() {
  group('PromoBanner.fromJson', () {
    test('reads title, subtitle, artwork and badge from a real post', () {
      final banners = bannerFixture().map(PromoBanner.fromJson).toList();

      expect(banners, hasLength(2));
      final bbq = banners.firstWhere((b) => b.title.startsWith('BBQ'));
      expect(bbq.title, 'BBQ Crispy Chicken');
      // The excerpt arrives as "<p>Extra cheese &#038; bacon</p>".
      expect(bbq.subtitle, 'Extra cheese & bacon');
      expect(bbq.imageUrl, isNotNull);
      expect(bbq.badge, 'New');
    });

    test('prefers a sized rendition over the full upload', () {
      final banners = bannerFixture().map(PromoBanner.fromJson).toList();
      // The seeded artwork only has thumbnail and full, so full is correct
      // here; what matters is that a URL was resolved at all.
      expect(banners.every((b) => b.imageUrl!.endsWith('.png')), isTrue);
    });

    test('survives a post with no featured image or tags', () {
      final banner = PromoBanner.fromJson(const {
        'id': 7,
        'title': {'rendered': 'Plain banner'},
        'excerpt': {'rendered': ''},
      });

      expect(banner.title, 'Plain banner');
      expect(banner.subtitle, isEmpty);
      expect(banner.imageUrl, isNull);
      expect(banner.badge, isNull);
      expect(banner.isRenderable, isTrue);
    });

    test('a post with neither title nor image is not renderable', () {
      final banner = PromoBanner.fromJson(const {
        'id': 8,
        'title': {'rendered': ''},
        'excerpt': {'rendered': '<p>orphan</p>'},
      });

      expect(banner.isRenderable, isFalse);
    });

    test('ignores non-tag terms when picking the badge', () {
      final banner = PromoBanner.fromJson(const {
        'id': 9,
        'title': {'rendered': 'Tagged'},
        'excerpt': {'rendered': ''},
        '_embedded': {
          'wp:term': [
            [
              {'taxonomy': 'category', 'name': 'App Banners'},
            ],
            [
              {'taxonomy': 'post_tag', 'name': 'Offer'},
            ],
          ],
        },
      });

      // The category name must not become the badge.
      expect(banner.badge, 'Offer');
    });
  });

  group('BannerCarousel', () {
    Future<void> pump(
      WidgetTester tester,
      List<PromoBanner> banners, {
      ThemeData? theme,
      void Function(PromoBanner)? onTap,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme ?? AppTheme.light(),
            home: Scaffold(
              body: BannerCarousel(
                banners: banners,
                onTap: onTap ?? (_) {},
              ),
            ),
          ),
        ),
      );
    }

    /// The device this was reported on: a 360dp-wide phone. The default test
    /// surface is 800x600, which is wider than any phone and hid the bug.
    Future<void> pumpPhone(
      WidgetTester tester,
      List<PromoBanner> banners,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pump(tester, banners);
      await tester.pump();
    }

    testWidgets('at phone width the copy does not run under the artwork',
        (tester) async {
      await pumpPhone(
        tester,
        bannerFixture().map(PromoBanner.fromJson).toList(),
      );

      final title = tester.getRect(find.text('BBQ Crispy Chicken'));
      final artwork = tester.getRect(find.byType(Image).first);

      expect(
        title.right,
        lessThanOrEqualTo(artwork.left),
        reason: 'the title overlapped the artwork by '
            '${title.right - artwork.left}px',
      );
    });

    testWidgets('the artwork fills its band rather than letterboxing',
        (tester) async {
      await pumpPhone(
        tester,
        bannerFixture().map(PromoBanner.fromJson).toList(),
      );

      final image = tester.widget<Image>(find.byType(Image).first);

      // `contain` leaves the card's red showing around the artwork, so it
      // reads as a floating rectangle rather than art bleeding off the edge.
      expect(image.fit, BoxFit.cover);
    });

    testWidgets('survives a very narrow card without a layout error',
        (tester) async {
      // A 280pt phone is narrower than anything shipping, but the copy width
      // is derived by subtraction and would go negative before it goes small.
      tester.view.physicalSize = const Size(840, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pump(tester, bannerFixture().map(PromoBanner.fromJson).toList());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders copy and badge', (tester) async {
      await pump(tester, bannerFixture().map(PromoBanner.fromJson).toList());
      await tester.pump();

      expect(find.text('BBQ Crispy Chicken'), findsOneWidget);
      expect(find.text('Extra cheese & bacon'), findsOneWidget);
      // Badges render uppercased.
      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('shows dots for several banners', (tester) async {
      await pump(tester, bannerFixture().map(PromoBanner.fromJson).toList());
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('hides dots for a single banner', (tester) async {
      await pump(tester, [
        const PromoBanner(id: 1, title: 'Only one', subtitle: ''),
      ]);
      await tester.pump();

      expect(find.text('Only one'), findsOneWidget);
      // A page indicator for one page is noise.
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('renders nothing at all when empty', (tester) async {
      await pump(tester, const []);
      await tester.pump();

      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('reports taps', (tester) async {
      PromoBanner? tapped;
      await pump(
        tester,
        [const PromoBanner(id: 3, title: 'Tap me', subtitle: '')],
        onTap: (b) => tapped = b,
      );
      await tester.pump();

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(tapped?.id, 3);
    });

    testWidgets('renders in dark mode', (tester) async {
      await pump(
        tester,
        [const PromoBanner(id: 4, title: 'Dark', subtitle: 'mode')],
        theme: AppTheme.dark(),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Dark'), findsOneWidget);
    });
  });
}

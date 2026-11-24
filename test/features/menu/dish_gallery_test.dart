import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/core/widgets/dish_image_placeholder.dart';
import 'package:food_menu/src/features/menu/data/addons_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/data/reviews_repository.dart';
import 'package:food_menu/src/features/menu/presentation/product_detail_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_gallery.dart';

import 'fake_addons_repository.dart';
import 'fake_menu_repository.dart';
import 'fake_reviews_repository.dart';

/// The dish gallery, task 15.2.
///
/// `Image.network` resolves in these tests against `flutter_test`'s own HTTP
/// stub, which answers every request with a transparent placeholder image. So
/// these say what is *built* — how many pages, which one is open, what a tap
/// pushes — and nothing about what a photograph looks like, which is a
/// person's job on a handset.
///
/// **One behaviour is deliberately not covered here**: paging is switched off
/// while a photo is zoomed. It is driven by the `InteractiveViewer`'s
/// transformation, which a test can only move by synthesising a two-finger
/// pinch against a widget it does not own a handle to. Exposing the
/// controller purely so a test could reach it would be inventing API for the
/// test's convenience. It was checked on the handset instead.
Product fromFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return Product.fromJson(json as Map<String, dynamic>);
}

/// The same fixture with a chosen number of photos on it.
Product withImages(String name, int count) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
      as Map<String, dynamic>;

  json['images'] = [
    for (var i = 0; i < count; i++)
      {
        'id': 200 + i,
        'src': 'https://example.test/photo-$i.jpg',
        'thumbnail': 'https://example.test/photo-$i-150.jpg',
        'alt': '',
      },
  ];

  return Product.fromJson(json);
}

void main() {
  Future<void> pump(WidgetTester tester, Product product) async {
    final repo = FakeMenuRepository()..single = product;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuRepositoryProvider.overrideWithValue(repo),
          addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
          reviewsRepositoryProvider.overrideWithValue(FakeReviewsRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProductDetailScreen(productId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The dots, by the shape the gallery draws them in: 6dp tall, 18 wide for
  /// the one you are on and 6 for the rest.
  Finder dots() => find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final constraints = widget.constraints;
        return constraints != null &&
            constraints.maxHeight == 6 &&
            (constraints.maxWidth == 6 || constraints.maxWidth == 18);
      });

  group('on the dish screen', () {
    testWidgets('a dish with three photos gets three pages and three dots',
        (tester) async {
      await pump(tester, fromFixture('product_gallery'));

      final gallery = tester.widget<DishGallery>(find.byType(DishGallery));
      expect(gallery.images, hasLength(3));
      expect(dots(), findsNWidgets(3));
    });

    testWidgets('a dish with one photo gets no dots', (tester) async {
      await pump(tester, withImages('product_gallery', 1));

      // The gallery is still there — one photo is still tappable.
      expect(find.byType(DishGallery), findsOneWidget);
      expect(dots(), findsNothing);
    });

    testWidgets('a dish with no photo keeps the placeholder', (tester) async {
      await pump(tester, fromFixture('product_simple'));

      expect(find.byType(DishImagePlaceholder), findsWidgets);
      expect(dots(), findsNothing);
    });

    testWidgets('swiping moves to the next photo', (tester) async {
      await pump(tester, fromFixture('product_gallery'));

      final page = tester.widget<PageView>(find.byType(PageView).first);
      expect(page.controller?.page?.round(), 0);

      await tester.drag(find.byType(PageView).first, const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<PageView>(find.byType(PageView).first)
            .controller
            ?.page
            ?.round(),
        1,
      );
    });
  });

  group('the full-screen viewer', () {
    testWidgets('a tap on the photo opens it', (tester) async {
      await pump(tester, fromFixture('product_gallery'));

      expect(find.byType(DishGalleryViewer), findsNothing);

      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();

      expect(find.byType(DishGalleryViewer), findsOneWidget);
    });

    testWidgets('it opens on the photo that was tapped, not the first',
        (tester) async {
      await pump(tester, fromFixture('product_gallery'));

      // Move the hero to the third photo first, so "the one tapped" and "the
      // first" cannot be the same answer.
      await tester.drag(find.byType(PageView).first, const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView).first, const Offset(-600, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();

      final viewer =
          tester.widget<DishGalleryViewer>(find.byType(DishGalleryViewer));
      expect(viewer.initialIndex, 2);
    });

    testWidgets('the close button dismisses it', (tester) async {
      await pump(tester, fromFixture('product_gallery'));

      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();
      expect(find.byType(DishGalleryViewer), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close photo'));
      await tester.pumpAndSettle();

      expect(find.byType(DishGalleryViewer), findsNothing);
    });

    testWidgets('swiping inside it moves between photos', (tester) async {
      // **The regression this exists for.** An `InteractiveViewer` that pans
      // takes the horizontal drag before the `PageView` beneath it sees one,
      // so the first build of the viewer opened correctly and then would not
      // swipe at all. Caught on the handset; this is the test that should
      // have caught it first.
      await pump(tester, fromFixture('product_gallery'));

      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();

      final pager = find.descendant(
        of: find.byType(DishGalleryViewer),
        matching: find.byType(PageView),
      );
      expect(tester.widget<PageView>(pager).controller?.page?.round(), 0);

      // **Dragged in steps, not in one jump.** `tester.drag` delivers the
      // whole movement as a single pointer event, and the horizontal drag
      // recognizer then wins the arena before the scale recognizer has seen
      // enough to claim it — so the one-jump version of this test passes
      // against the broken widget. A real finger arrives as a stream of
      // small moves, which is what decides it the other way on a handset.
      final gesture = await tester.startGesture(tester.getCenter(pager));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.widget<PageView>(pager).controller?.page?.round(), 1);
    });

    /// The scale the viewer is actually drawing the photo at.
    double scaleOf(WidgetTester tester) {
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(DishGalleryViewer),
          matching: find.byType(Transform),
        ),
      );
      return transforms
          .map((t) => t.transform.getMaxScaleOnAxis())
          .fold<double>(1, (a, b) => b > a ? b : a);
    }

    /// Two fingers moving apart from the middle of the viewer.
    Future<void> pinchOut(WidgetTester tester, Finder pager) async {
      final centre = tester.getCenter(pager);
      final left = await tester.startGesture(centre - const Offset(20, 0));
      final right = await tester.startGesture(centre + const Offset(20, 0));
      for (var i = 0; i < 10; i++) {
        await left.moveBy(const Offset(-8, 0));
        await right.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a pinch zooms the photo', (tester) async {
      await pump(tester, fromFixture('product_gallery'));
      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();

      final pager = find.descendant(
        of: find.byType(DishGalleryViewer),
        matching: find.byType(PageView),
      );
      expect(scaleOf(tester), 1);

      await pinchOut(tester, pager);

      expect(scaleOf(tester), greaterThan(1));
    });

    testWidgets('a zoomed photo pans instead of turning the page',
        (tester) async {
      // The other half of the bargain: one finger pages while the photo is
      // whole, and moves the photo once it is not.
      await pump(tester, fromFixture('product_gallery'));
      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();

      final pager = find.descendant(
        of: find.byType(DishGalleryViewer),
        matching: find.byType(PageView),
      );
      await pinchOut(tester, pager);
      expect(scaleOf(tester), greaterThan(1));

      final gesture = await tester.startGesture(tester.getCenter(pager));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.widget<PageView>(pager).controller?.page?.round(), 0);
    });

    testWidgets('a double tap zooms in, and again zooms back out',
        (tester) async {
      await pump(tester, fromFixture('product_gallery'));
      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();

      final pager = find.descendant(
        of: find.byType(DishGalleryViewer),
        matching: find.byType(PageView),
      );
      final centre = tester.getCenter(pager);

      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(centre);
      await tester.pumpAndSettle();
      expect(scaleOf(tester), greaterThan(1));

      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(centre);
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1);
    });

    testWidgets('turning the page puts the last photo back to fit',
        (tester) async {
      await pump(tester, fromFixture('product_gallery'));
      await tester.tap(find.byType(DishGallery));
      await tester.pumpAndSettle();

      final pager = find.descendant(
        of: find.byType(DishGalleryViewer),
        matching: find.byType(PageView),
      );
      await pinchOut(tester, pager);
      expect(scaleOf(tester), greaterThan(1));

      // Zoom out again so the page can turn at all, then turn it.
      final centre = tester.getCenter(pager);
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(centre);
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(centre);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.widget<PageView>(pager).controller?.page?.round(), 1);
      expect(scaleOf(tester), 1);
    });

    testWidgets('every photo is labelled for a screen reader', (tester) async {
      await pump(tester, fromFixture('product_gallery'));

      // The first carries the store's own alt text; the other two have none
      // in the fixture and fall back to their position.
      expect(
        find.bySemanticsLabel('Biryani in a copper pot'),
        findsOneWidget,
      );

      await tester.drag(find.byType(PageView).first, const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Photo 2 of 3'), findsOneWidget);
    });
  });
}

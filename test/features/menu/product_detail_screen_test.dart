import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/presentation/product_detail_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/food_tags.dart';

import 'fake_menu_repository.dart';

Product fromFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return Product.fromJson(json as Map<String, dynamic>);
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Product? product,
    Object? error,
    ThemeData? theme,
  }) async {
    final repo = FakeMenuRepository()
      ..single = product
      ..productError = error;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [menuRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: const ProductDetailScreen(productId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('simple dish', () {
    testWidgets('shows name, price and a working add button', (tester) async {
      await pump(tester, product: fromFixture('product_simple'));

      expect(find.text('Iced Latte'), findsOneWidget);
      // Twice: the unit price in the body and the line total in the add bar,
      // which are the same string at quantity 1.
      expect(find.text(r'$3.95'), findsNWidgets(2));
      expect(find.text('Add to cart'), findsOneWidget);
    });

    testWidgets('the line total tracks the quantity', (tester) async {
      await pump(tester, product: fromFixture('product_simple'));

      // Quantity 1: one unit.
      expect(find.text(r'$3.95'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text(r'$7.90'), findsOneWidget);
    });

    testWidgets('quantity cannot go below one', (tester) async {
      await pump(tester, product: fromFixture('product_simple'));

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Removing the line is the cart's job, not the stepper's.
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('discounted dish', () {
    testWidgets('strikes through the regular price', (tester) async {
      await pump(tester, product: fromFixture('product_on_sale'));

      expect(find.text(r'$4.95'), findsWidgets);
      final struck = tester.widget<Text>(find.text(r'$5.95'));
      expect(struck.style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('variable dish', () {
    testWidgets('shows a price range, not a single price', (tester) async {
      await pump(tester, product: fromFixture('product_variable'));

      expect(find.text('Build Your Pizza'), findsOneWidget);
      expect(find.text('from'), findsOneWidget);
      expect(find.text(r'$8.50'), findsOneWidget);
      expect(find.text(r'to $15.00'), findsOneWidget);
    });

    testWidgets('asks for options instead of offering a total', (tester) async {
      await pump(tester, product: fromFixture('product_variable'));

      // A line total before a variation is chosen would be a guess.
      expect(find.text('Choose options'), findsOneWidget);
      expect(find.text('Add to cart'), findsNothing);
    });
  });

  group('out of stock dish', () {
    testWidgets('uses the site own stock wording', (tester) async {
      await pump(tester, product: fromFixture('product_out_of_stock'));

      expect(find.text('Out of stock'), findsOneWidget);
    });

    testWidgets('never renders "Only 0 left"', (tester) async {
      final product = fromFixture('product_out_of_stock');

      // The API sends low_stock_remaining: 0 alongside is_in_stock: false.
      expect(product.lowStockRemaining, 0);
      expect(product.lowStockWarning, isNull);

      await pump(tester, product: product);
      expect(find.textContaining('Only 0'), findsNothing);
    });

    testWidgets('is purchasable per the API, but still not orderable',
        (tester) async {
      final product = fromFixture('product_out_of_stock');

      // is_purchasable stays true when sold out, so it alone is not enough.
      expect(product.isPurchasable, isTrue);
      expect(product.isInStock, isFalse);
      expect(product.isOrderable, isFalse);
    });

    testWidgets('disables the add button and the stepper', (tester) async {
      await pump(tester, product: fromFixture('product_out_of_stock'));

      expect(find.text('Unavailable'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('low stock', () {
    testWidgets('warns with the remaining count', (tester) async {
      final product = Product.fromJson({
        'id': 5,
        'name': 'Lamb Biryani',
        'prices': const {
          'price': '1495',
          'currency_minor_unit': 2,
          'currency_prefix': r'$',
        },
        'is_in_stock': true,
        'is_purchasable': true,
        'low_stock_remaining': 2,
      });
      await pump(tester, product: product);

      expect(find.text('Only 2 left'), findsOneWidget);
      expect(find.text('Add to cart'), findsOneWidget);
    });
  });

  group('failures', () {
    testWidgets('a 404 says the dish is gone', (tester) async {
      await pump(
        tester,
        error: const ApiException(
          failure: ApiFailure.http,
          message: 'Invalid product ID.',
          statusCode: 404,
          code: 'woocommerce_rest_product_invalid_id',
        ),
      );

      expect(find.text('This dish is no longer on the menu.'), findsOneWidget);
    });

    testWidgets('other failures show the server message', (tester) async {
      await pump(
        tester,
        error: const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server. Check your connection.',
        ),
      );

      expect(
        find.text('Could not reach the server. Check your connection.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('strips HTML from the description', (tester) async {
    await pump(tester, product: fromFixture('product_simple'));

    expect(find.text('Double espresso over milk and ice.'), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
  });

  group('food tags', () {
    testWidgets('renders tags from the real variable fixture', (tester) async {
      await pump(tester, product: fromFixture('product_variable'));

      // Seeded on the dev site as product_tag terms.
      expect(find.text('Vegetarian'), findsOneWidget);
      expect(find.text('Shareable'), findsOneWidget);
    });

    testWidgets('gives known dietary slugs an icon', (tester) async {
      await pump(tester, product: fromFixture('product_variable'));

      expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
    });

    testWidgets('an unknown tag still renders, just without an icon',
        (tester) async {
      final product = Product.fromJson({
        'id': 9,
        'name': 'Chef Special',
        'prices': const {
          'price': '1200',
          'currency_minor_unit': 2,
          'currency_prefix': r'$',
        },
        'tags': const [
          {'id': 1, 'name': 'Chef Pick', 'slug': 'chef-pick'},
        ],
      });
      await pump(tester, product: product);

      expect(find.text('Chef Pick'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no tag section when a dish has none', (tester) async {
      await pump(tester, product: fromFixture('product_simple'));

      expect(find.byType(FoodTags), findsNothing);
    });
  });

  testWidgets('renders in dark mode without error', (tester) async {
    await pump(
      tester,
      product: fromFixture('product_variable'),
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Build Your Pizza'), findsOneWidget);
  });
}

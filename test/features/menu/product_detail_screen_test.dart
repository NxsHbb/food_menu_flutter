import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/data/addons_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/data/reviews_repository.dart';
import 'package:food_menu/src/features/menu/presentation/product_detail_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/food_data_section.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/food_tags.dart';

import 'fake_addons_repository.dart';
import 'fake_menu_repository.dart';
import 'fake_reviews_repository.dart';

Product fromFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return Product.fromJson(json as Map<String, dynamic>);
}

/// The same fixture with the store having hidden some of the dish screen.
///
/// Only the named sections are turned off, so a test says what it is about
/// and nothing else moves.
Product withHidden(String name, List<String> hidden) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
      as Map<String, dynamic>;

  final extensions = (json['extensions'] as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};
  final foodMenu =
      (extensions['food-menu-pro'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

  foodMenu['sections'] = {
    for (final key in const [
      'image',
      'price',
      'summary',
      'taxonomy',
      'description',
      'ingredients',
      'nutrition',
      'reviews',
    ])
      key: !hidden.contains(key),
  };

  extensions['food-menu-pro'] = foodMenu;
  json['extensions'] = extensions;

  return Product.fromJson(json);
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Product? product,
    Object? error,
    ThemeData? theme,
    FakeReviewsRepository? reviews,
  }) async {
    final repo = FakeMenuRepository()
      ..single = product
      ..productError = error;
    final reviewRepo = reviews ?? FakeReviewsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuRepositoryProvider.overrideWithValue(repo),
          // These dishes have no add-ons; the groups have their own test
          // file. Overridden so no test reaches for the network.
          addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
          reviewsRepositoryProvider.overrideWithValue(reviewRepo),
        ],
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

  group('outside its hours', () {
    testWidgets('says why in the store own words and refuses the add',
        (tester) async {
      await pump(
        tester,
        product: buildProduct(
          id: 14,
          name: 'Margherita',
          timedAvailable: false,
          timedNote: 'Will be Available: 8:00 am – 11:00 am',
        ),
      );

      expect(
        find.text('Will be Available: 8:00 am – 11:00 am'),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('warns a dish that is about to go off the menu',
        (tester) async {
      await pump(
        tester,
        product: buildProduct(
          id: 22,
          name: 'Mushroom Risotto',
          timedAvailable: true,
          timedNote: 'Will be Unavailable: 11:00 pm – 11:59 pm',
        ),
      );

      // Still orderable: the note is a heads-up, not a refusal.
      expect(
        find.text('Will be Unavailable: 11:00 pm – 11:59 pm'),
        findsOneWidget,
      );
      expect(find.text('Add to cart'), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
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
      // Nothing to retry: asking again fetches the same 404, and a button
      // that cannot work is worse than no button.
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Back to the menu'), findsOneWidget);
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
      // **The screen used to be a dead end.** A dropped connection lost the
      // dish the customer picked, with only a way back to the menu.
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the retry re-asks for the dish', (tester) async {
      final repo = FakeMenuRepository()
        ..productError = const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server. Check your connection.',
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            menuRepositoryProvider.overrideWithValue(repo),
            addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
            reviewsRepositoryProvider
                .overrideWithValue(FakeReviewsRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProductDetailScreen(productId: 26),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The dish is there on the second ask.
      repo
        ..productError = null
        ..single = fromFixture('product_simple');

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Iced Latte'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
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

  group('ingredients and nutrition', () {
    testWidgets('renders both sections from the real payload', (tester) async {
      await pump(tester, product: fromFixture('product_with_food_data'));

      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Nutrition facts'), findsOneWidget);
      expect(find.text('Mozzarella'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
    });

    testWidgets('joins the value and unit', (tester) async {
      await pump(tester, product: fromFixture('product_with_food_data'));

      expect(find.text('120 g'), findsOneWidget);
      expect(find.text('540 kcal'), findsOneWidget);
    });

    testWidgets('a row with no amount still renders its name',
        (tester) async {
      final product = Product.fromJson({
        'id': 50,
        'name': 'Herb Salad',
        'prices': const {
          'price': '700',
          'currency_minor_unit': 2,
          'currency_prefix': r'$',
        },
        'extensions': const {
          'food-menu-pro': {
            'ingredients': [
              {'id': 1, 'name': 'Basil', 'value': '', 'unit': ''},
            ],
            'nutrition': <dynamic>[],
          },
        },
      });
      await pump(tester, product: product);

      // Amount is optional in the admin, so a bare name is valid.
      expect(find.text('Basil'), findsOneWidget);
      expect(find.text('Nutrition facts'), findsNothing);
    });

    testWidgets('no sections when a dish has no food data', (tester) async {
      await pump(tester, product: fromFixture('product_simple'));

      expect(find.byType(FoodDataSection), findsNothing);
      expect(find.text('Ingredients'), findsNothing);
    });

    testWidgets('tolerates a site whose plugin predates the extension',
        (tester) async {
      // No extensions block at all — must not throw, must show no sections.
      final product = Product.fromJson({
        'id': 51,
        'name': 'Old Site Dish',
        'prices': const {
          'price': '500',
          'currency_minor_unit': 2,
          'currency_prefix': r'$',
        },
      });
      await pump(tester, product: product);

      expect(tester.takeException(), isNull);
      expect(find.byType(FoodDataSection), findsNothing);
    });

    testWidgets('skips a malformed row rather than rendering a blank line',
        (tester) async {
      final product = Product.fromJson({
        'id': 52,
        'name': 'Odd Dish',
        'prices': const {
          'price': '500',
          'currency_minor_unit': 2,
          'currency_prefix': r'$',
        },
        'extensions': const {
          'food-menu-pro': {
            'ingredients': [
              {'id': 1, 'name': '', 'value': '10', 'unit': 'g'},
              {'id': 2, 'name': 'Olive Oil', 'value': '10', 'unit': 'ml'},
            ],
          },
        },
      });
      await pump(tester, product: product);

      expect(find.text('Olive Oil'), findsOneWidget);
      expect(product.ingredients, hasLength(1));
    });

    testWidgets('renders in dark mode', (tester) async {
      await pump(
        tester,
        product: fromFixture('product_with_food_data'),
        theme: AppTheme.dark(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Mozzarella'), findsOneWidget);
    });
  });

  group('the sections the store switched off (task 10.1)', () {
    testWidgets('draws everything when the store hid nothing', (tester) async {
      await pump(tester, product: withHidden('product_with_food_data', []));

      expect(find.byType(FoodDataSection), findsNWidgets(2));
      expect(find.text('Mozzarella'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
    });

    testWidgets('a hidden price takes the add bar with it', (tester) async {
      // The website renders the price and the add-to-cart button inside one
      // condition, so honouring half of it would price nothing and offer to
      // charge for it.
      await pump(tester, product: withHidden('product_simple', ['price']));

      expect(find.text('Iced Latte'), findsOneWidget);
      expect(find.text(r'$3.95'), findsNothing);
      expect(find.text('Add to cart'), findsNothing);
    });

    testWidgets('a hidden image keeps the way off the screen', (tester) async {
      // The photo shares its box with the close button and the heart, so
      // dropping the hero would strand the customer.
      await pump(tester, product: withHidden('product_simple', ['image']));

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      // Everything else still drawn.
      expect(find.text('Iced Latte'), findsOneWidget);
      expect(find.text('Add to cart'), findsOneWidget);
    });

    testWidgets('a hidden description leaves the rest alone', (tester) async {
      await pump(
        tester,
        product: withHidden('product_with_food_data', ['description']),
      );

      expect(find.byType(FoodDataSection), findsNWidgets(2));
      expect(find.text('Add to cart'), findsOneWidget);
    });

    testWidgets('hidden food data drops both sections', (tester) async {
      await pump(
        tester,
        product: withHidden(
          'product_with_food_data',
          ['ingredients', 'nutrition'],
        ),
      );

      expect(find.byType(FoodDataSection), findsNothing);
      expect(find.text('Mozzarella'), findsNothing);
      expect(find.text('Calories'), findsNothing);
    });

    testWidgets('one of the two can go without the other', (tester) async {
      await pump(
        tester,
        product: withHidden('product_with_food_data', ['nutrition']),
      );

      expect(find.byType(FoodDataSection), findsOneWidget);
      expect(find.text('Mozzarella'), findsOneWidget);
      expect(find.text('Calories'), findsNothing);
    });

    testWidgets('a hidden taxonomy drops the food tags', (tester) async {
      await pump(
        tester,
        product: withHidden('product_with_food_data', ['taxonomy']),
      );

      expect(find.byType(FoodTags), findsNothing);
    });

    testWidgets('hidden reviews say nothing at all about reviews',
        (tester) async {
      // Including the "No reviews yet" line: a store with comments closed
      // was being told it has no reviews yet, which is the website saying
      // nothing and the app saying something.
      await pump(tester, product: withHidden('product_simple', ['reviews']));

      expect(find.text('No reviews yet'), findsNothing);
      expect(find.textContaining('reviews)'), findsNothing);
    });

    testWidgets('the card fills the screen when little is left on it',
        (tester) async {
      // Found on the device: with the image and the reviews hidden, the card
      // carrying the screen's surface colour ended mid-screen and the page
      // colour showed through to the add bar. A structural assertion rather
      // than a pixel one — `SliverToBoxAdapter` is what the bug was, and
      // swapping it back is what the regression would be.
      await pump(
        tester,
        product: withHidden('product_simple', ['image', 'reviews']),
      );

      expect(find.byType(SliverFillRemaining), findsOneWidget);
      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
    });

    testWidgets('everything off still renders', (tester) async {
      await pump(
        tester,
        product: withHidden('product_with_food_data', [
          'image',
          'price',
          'summary',
          'taxonomy',
          'description',
          'ingredients',
          'nutrition',
          'reviews',
        ]),
      );

      expect(tester.takeException(), isNull);
      // The name and the way out are not the store's to hide.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(FoodDataSection), findsNothing);
      expect(find.text('Add to cart'), findsNothing);
    });
  });

  group('reviews (task 10.3)', () {
    testWidgets('lists what other customers said', (tester) async {
      final reviews = FakeReviewsRepository(
        stored: [
          buildReview(id: 1, reviewer: 'Ayesha R.', review: 'Best in the city.'),
          buildReview(id: 2, reviewer: 'Tom B.', review: 'Ordered it twice.'),
        ],
      );
      await pump(
        tester,
        product: fromFixture('product_simple'),
        reviews: reviews,
      );

      expect(find.text('Reviews (2)'), findsOneWidget);
      expect(find.text('Ayesha R.'), findsOneWidget);
      expect(find.text('Best in the city.'), findsOneWidget);
      expect(find.text('Ordered it twice.'), findsOneWidget);
    });

    testWidgets('says so when there are none', (tester) async {
      await pump(tester, product: fromFixture('product_simple'));

      expect(find.text('No reviews yet. Be the first.'), findsOneWidget);
    });

    testWidgets('a failed read costs the section, not the screen',
        (tester) async {
      final reviews = FakeReviewsRepository()
        ..failNext = const ApiException(
          failure: ApiFailure.network,
          message: 'offline',
        );
      await pump(
        tester,
        product: fromFixture('product_simple'),
        reviews: reviews,
      );

      expect(find.text('Reviews could not be loaded.'), findsOneWidget);
      // The dish is still orderable.
      expect(find.text('Add to cart'), findsOneWidget);
    });

    testWidgets('marks a verified order', (tester) async {
      final reviews = FakeReviewsRepository(
        stored: [buildReview(verified: true)],
      );
      await pump(
        tester,
        product: fromFixture('product_simple'),
        reviews: reviews,
      );

      expect(find.text('Verified order'), findsOneWidget);
    });

    testWidgets('offers the rest, and loads them', (tester) async {
      final reviews = FakeReviewsRepository(
        stored: [
          for (var i = 1; i <= 5; i++)
            buildReview(id: i, reviewer: 'Reviewer $i', review: 'Review $i'),
        ],
      );
      await pump(
        tester,
        product: fromFixture('product_simple'),
        reviews: reviews,
      );

      // Three at a time, so two are held back.
      expect(find.text('Review 3'), findsOneWidget);
      expect(find.text('Review 4'), findsNothing);
      expect(find.text('Show more (2)'), findsOneWidget);

      // The section is the last thing on a long screen, so it is built but
      // below the fold at this viewport.
      await tester.ensureVisible(find.text('Show more (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show more (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Review 4'), findsOneWidget);
      expect(find.text('Review 5'), findsOneWidget);
      expect(find.text('Show more (2)'), findsNothing);
      expect(reviews.calls.last, endsWith('page 2'));
    });

    testWidgets('names the store condition without claiming the answer',
        (tester) async {
      // Whether *this* customer qualifies is a per-customer question the
      // product payload cannot answer, so the condition is stated and the
      // verdict is left to the refusal.
      final product = Product.fromJson({
        'id': 17,
        'name': 'Iced Latte',
        'prices': const {'price': '395', 'currency_minor_unit': 2},
        'extensions': const {
          'food-menu-pro': {
            'reviews': {'enabled': true, 'verification_required': true},
          },
        },
      });
      await pump(tester, product: product);

      expect(
        find.text('Only customers who have ordered this dish can review it.'),
        findsOneWidget,
      );
      // Still offered — the server decides.
      expect(find.text('Write a review'), findsOneWidget);
    });

    testWidgets('a store that takes no reviews is not offered the form',
        (tester) async {
      final product = Product.fromJson({
        'id': 17,
        'name': 'Iced Latte',
        'prices': const {'price': '395', 'currency_minor_unit': 2},
        'extensions': const {
          'food-menu-pro': {
            'reviews': {'enabled': false},
          },
        },
      });
      await pump(tester, product: product);

      expect(find.text('Write a review'), findsNothing);
      expect(find.text('No reviews yet.'), findsOneWidget);
    });

    testWidgets('hidden reviews take the whole section with them',
        (tester) async {
      // Task 10.1's switch governs this section too, which is the gate 10.3
      // was planned behind.
      final reviews = FakeReviewsRepository(stored: [buildReview()]);
      await pump(
        tester,
        product: withHidden('product_simple', ['reviews']),
        reviews: reviews,
      );

      expect(find.text('Reviews'), findsNothing);
      expect(find.text('Reviews (1)'), findsNothing);
      expect(find.text('Write a review'), findsNothing);
      // Never even asked.
      expect(reviews.calls, isEmpty);
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

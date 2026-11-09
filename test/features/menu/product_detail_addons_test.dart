import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/data/addons_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/presentation/product_detail_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/addon_group_card.dart';

import 'fake_addons_repository.dart';
import 'fake_menu_repository.dart';

Product productFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return Product.fromJson(json as Map<String, dynamic>);
}

/// The dish fixture's own add-ons, with every `is_default` cleared.
///
/// The real payload pre-selects `Small 9"`, which is the store answering its
/// own required question — so the "nothing chosen yet" paths need a dish
/// whose required group genuinely starts empty.
ProductAddons withoutDefaults(String fixture) {
  final json = jsonDecode(File('test/fixtures/$fixture.json').readAsStringSync())
      as Map<String, dynamic>;

  for (final group in (json['groups'] as List).cast<Map<String, dynamic>>()) {
    for (final option in (group['options'] as List).cast<Map<String, dynamic>>()) {
      option['is_default'] = false;
    }
  }

  return ProductAddons.fromJson(json);
}

/// The running total, scoped to the add button — the dish's own price is on
/// the page too, so a bare text finder would match either.
Finder total(String amount) => find.descendant(
      of: find.byType(FilledButton),
      matching: find.text(amount),
    );

/// Taps something inside the scrolling body.
///
/// The groups sit below the fold at the test surface's size, and a tap on an
/// off-screen widget lands on nothing at all — quietly, which is how it ends
/// up looking like the screen ignored it.
Future<void> tapInBody(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAddonsRepository addonsRepo;

  /// `product_simple` is the Iced Latte at $3.95, which is the base every
  /// total below builds on.
  Future<void> pump(
    WidgetTester tester, {
    ProductAddons? addons,
    Object? addonsError,
    ThemeData? theme,
  }) async {
    final menu = FakeMenuRepository()..single = productFixture('product_simple');
    addonsRepo = FakeAddonsRepository(addons: addons, error: addonsError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuRepositoryProvider.overrideWithValue(menu),
          addonsRepositoryProvider.overrideWithValue(addonsRepo),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: const ProductDetailScreen(productId: 25),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a dish with groups', () {
    testWidgets('draws every group with its options', (tester) async {
      await pump(tester, addons: addonsFromFixture('product_addons'));

      expect(find.byType(AddonGroupCard), findsNWidgets(3));
      expect(find.text('Choose your size'), findsOneWidget);
      expect(find.text('Medium 12"'), findsOneWidget);
      expect(find.text('Extra toppings'), findsOneWidget);
      expect(find.text('Anything else?'), findsOneWidget);
    });

    testWidgets('a default answer arrives already chosen', (tester) async {
      // The store pre-selects `Small 9"`, so its required group opens as Done
      // rather than as a question the customer has not been asked yet.
      await pump(tester, addons: addonsFromFixture('product_addons'));

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Required'), findsNothing);
      expect(find.text('Add to cart'), findsOneWidget);
    });

    testWidgets('labels what each group expects', (tester) async {
      await pump(tester, addons: withoutDefaults('product_addons'));

      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Optional'), findsNWidgets(2));
      expect(find.text('Select one'), findsOneWidget);
      expect(find.text('Select up to 3'), findsOneWidget);
      // The store's own words for the group sit alongside the rule, not
      // instead of it.
      expect(find.text('Every pizza is hand stretched.'), findsOneWidget);
    });

    testWidgets('prices options, and says Free where the store asks for it',
        (tester) async {
      await pump(tester, addons: addonsFromFixture('product_addons'));

      expect(find.text(r'+ $2.50'), findsOneWidget);
      expect(find.text(r'+ $4.00'), findsOneWidget);
      expect(find.text(r'+ $0.75'), findsOneWidget);
      // `Small 9"` and Basil cost nothing, and this store shows the badge.
      expect(find.text('Free'), findsNWidgets(2));
    });
  });

  group('the running total', () {
    testWidgets('starts at the dish price and follows each choice',
        (tester) async {
      await pump(tester, addons: withoutDefaults('product_addons'));

      expect(total(r'$3.95'), findsOneWidget);

      await tapInBody(tester, find.text('Medium 12"'));
      expect(total(r'$6.45'), findsOneWidget);

      await tapInBody(tester, find.text('Mushrooms'));
      expect(total(r'$7.20'), findsOneWidget);
    });

    testWidgets('multiplies the dish and its add-ons by the quantity',
        (tester) async {
      await pump(tester, addons: withoutDefaults('product_addons'));

      await tapInBody(tester, find.text('Medium 12"'));
      await tapInBody(tester, find.byIcon(Icons.add).last);

      // (3.95 + 2.50) × 2
      expect(total(r'$12.90'), findsOneWidget);
    });

    testWidgets('a per-option stepper raises that option only',
        (tester) async {
      await pump(tester, addons: withoutDefaults('product_addons'));

      await tapInBody(tester, find.text('Mushrooms'));
      expect(total(r'$4.70'), findsOneWidget);

      // The stepper only exists once the option is ticked, and it sits above
      // the bottom bar's own.
      await tapInBody(tester, find.byIcon(Icons.add).first);
      expect(total(r'$5.45'), findsOneWidget);
    });

    testWidgets('a dropdown group prices like any other one-of list',
        (tester) async {
      await pump(tester, addons: addonsFromFixture('product_addons_global'));

      await tapInBody(tester, find.text('Add fries & a drink'));

      // 3.95 + 3.25
      expect(total(r'$7.20'), findsOneWidget);
    });
  });

  group('choosing', () {
    testWidgets('a single-choice group replaces rather than accumulates',
        (tester) async {
      await pump(tester, addons: withoutDefaults('product_addons'));

      await tapInBody(tester, find.text('Medium 12"'));
      await tapInBody(tester, find.text('Large 15"'));

      // 3.95 + 4.00, not 3.95 + 2.50 + 4.00.
      expect(total(r'$7.95'), findsOneWidget);
    });

    testWidgets('a tick past the group maximum says so rather than nothing',
        (tester) async {
      await pump(
        tester,
        addons: ProductAddons.fromJson({
          'product_id': 25,
          'currency': {'currency_code': 'USD', 'currency_minor_unit': 2},
          'groups': [
            {
              'id': '0',
              'title': 'Sauces',
              'type': 'checkbox',
              'max_selection': 2,
              'options': [
                {'id': '0', 'label': 'Garlic', 'price': '0'},
                {'id': '1', 'label': 'Chilli', 'price': '0'},
                {'id': '2', 'label': 'Tahini', 'price': '0'},
              ],
            },
          ],
        }),
      );

      await tapInBody(tester, find.text('Garlic'));
      await tapInBody(tester, find.text('Chilli'));
      await tapInBody(tester, find.text('Tahini'));

      expect(find.text('Select up to 2 sauces.'), findsOneWidget);
    });
  });

  group('a required group still open', () {
    testWidgets('the button names it instead of adding', (tester) async {
      await pump(tester, addons: withoutDefaults('product_addons'));

      expect(find.text('Select choose your size'), findsOneWidget);
      expect(find.text('Add to cart'), findsNothing);

      await tester.tap(find.text('Select choose your size'));
      await tester.pumpAndSettle();

      expect(find.text('Choose choose your size first.'), findsOneWidget);
      expect(find.text('Please make a selection'), findsOneWidget);
    });

    testWidgets('answering it clears the error and frees the button',
        (tester) async {
      await pump(tester, addons: withoutDefaults('product_addons'));

      await tester.tap(find.text('Select choose your size'));
      await tester.pumpAndSettle();
      expect(find.text('Please make a selection'), findsOneWidget);

      await tapInBody(tester, find.text('Small 9"'));

      expect(find.text('Please make a selection'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Add to cart'), findsOneWidget);
    });
  });

  group('text groups', () {
    testWidgets('typing is kept', (tester) async {
      await pump(tester, addons: addonsFromFixture('product_addons'));

      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'No ice please');
      await tester.pumpAndSettle();

      expect(find.text('No ice please'), findsOneWidget);
    });
  });

  group('a store without the route', () {
    testWidgets('shows the dish with no groups rather than an error',
        (tester) async {
      // An older plugin answers 404, and a dish that cannot be customised is
      // still a perfectly good dish.
      await pump(tester, addonsError: StateError('404'));

      expect(find.byType(AddonGroupCard), findsNothing);
      expect(find.text('Add to cart'), findsOneWidget);
      expect(total(r'$3.95'), findsOneWidget);
      expect(addonsRepo.requested, [25]);
    });

    testWidgets('a dish with no add-ons behaves the same', (tester) async {
      await pump(tester);

      expect(find.byType(AddonGroupCard), findsNothing);
      expect(find.text('Add to cart'), findsOneWidget);
    });
  });

  testWidgets('groups render in dark mode without error', (tester) async {
    await pump(
      tester,
      addons: addonsFromFixture('product_addons'),
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AddonGroupCard), findsNWidgets(3));
  });
}

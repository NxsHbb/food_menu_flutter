import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/core/widgets/dish_image_placeholder.dart';
import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/presentation/menu_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/category_chips.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';

import 'fake_banner_repository.dart';
import 'fake_menu_repository.dart';

/// The chip, not the section header — after a category is selected its name
/// appears in both places.
Finder chip(String label) => find.descendant(
      of: find.byType(CategoryChips),
      matching: find.text(label),
    );

void main() {
  Future<FakeMenuRepository> pumpMenu(
    WidgetTester tester, {
    FakeMenuRepository? repository,
    ThemeData? theme,
  }) async {
    final repo = repository ?? FakeMenuRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuRepositoryProvider.overrideWithValue(repo),
          bannerRepositoryProvider.overrideWithValue(FakeBannerRepository()),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: const MenuScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('shows a loading indicator before data arrives', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(delay: const Duration(milliseconds: 50)),
          ),
          bannerRepositoryProvider.overrideWithValue(FakeBannerRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const MenuScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('a dish outside its hours reads as unavailable on its card',
      (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        productList: [
          buildProduct(
            id: 1,
            name: 'Margherita',
            timedAvailable: false,
            timedNote: 'Will be Available: 8:00 am – 11:00 am',
          ),
        ],
      ),
    );

    // The store's own words take the line a rating would have used, and the
    // photo dims rather than the card disappearing.
    expect(find.text('Will be Available: 8:00 am – 11:00 am'), findsOneWidget);
    expect(find.text('No reviews yet'), findsNothing);
    expect(find.byType(DishCard), findsOneWidget);

    final dimmed = tester.widgetList<Opacity>(find.byType(Opacity));
    expect(dimmed.any((o) => o.opacity < 1), isTrue);
  });

  testWidgets('renders a card per dish', (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        productList: [
          buildProduct(id: 1, name: 'Margherita'),
          buildProduct(id: 2, name: 'Pepperoni'),
        ],
      ),
    );

    expect(find.byType(DishCard), findsNWidgets(2));
    expect(find.text('Margherita'), findsOneWidget);
    expect(find.text('Pepperoni'), findsOneWidget);
  });

  testWidgets('formats the price in major units', (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        productList: [buildProduct(name: 'Garlic Bread', price: '450')],
      ),
    );

    // "450" is $4.50, not $450.
    expect(find.text(r'$4.50'), findsOneWidget);
    expect(find.text(r'$450.00'), findsNothing);
  });

  testWidgets('strikes through the regular price when discounted',
      (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        productList: [
          buildProduct(name: 'Cheesecake', price: '495', regularPrice: '595'),
        ],
      ),
    );

    expect(find.text(r'$4.95'), findsOneWidget);
    final struck = tester.widget<Text>(find.text(r'$5.95'));
    expect(struck.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('falls back to the stripe placeholder with no photo',
      (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(productList: [buildProduct()]),
    );

    expect(find.byType(DishImagePlaceholder), findsOneWidget);
  });

  testWidgets('hides the rating row until something is reviewed',
      (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        productList: [buildProduct(reviewCount: 0)],
      ),
    );

    // "★ 0.0 (0)" would read as a bad score rather than no score.
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('shows the rating once reviews exist', (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        productList: [buildProduct(reviewCount: 12, rating: '4.5')],
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('(12)'), findsOneWidget);
  });

  testWidgets('leads with an All chip and the category names', (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        categoryList: [
          buildCategory(id: 10, name: 'Pizza'),
          buildCategory(id: 11, name: 'Burgers'),
        ],
        productList: [buildProduct()],
      ),
    );

    expect(chip('All'), findsOneWidget);
    expect(chip('Pizza'), findsOneWidget);
    expect(chip('Burgers'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
  });

  testWidgets('tapping a category refetches scoped to it', (tester) async {
    final repo = await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        categoryList: [buildCategory(id: 10, name: 'Pizza')],
        productList: [
          buildProduct(
            id: 1,
            name: 'Margherita',
            categories: const [
              {'id': 10, 'name': 'Pizza', 'slug': 'pizza'},
            ],
          ),
        ],
      ),
    );

    expect(repo.requestedCategories, [null]);

    await tester.tap(chip('Pizza'));
    await tester.pumpAndSettle();

    expect(repo.requestedCategories, [null, 10]);
    // The section title follows the selection.
    expect(find.text('Popular'), findsNothing);
  });

  testWidgets('tapping the selected category again clears the filter',
      (tester) async {
    final repo = await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        categoryList: [buildCategory(id: 10, name: 'Pizza')],
        productList: [buildProduct()],
      ),
    );

    await tester.tap(chip('Pizza'));
    await tester.pumpAndSettle();
    await tester.tap(chip('Pizza'));
    await tester.pumpAndSettle();

    expect(repo.requestedCategories, [null, 10, null]);
  });

  testWidgets('shows an empty state rather than a blank grid', (tester) async {
    await pumpMenu(tester, repository: FakeMenuRepository());

    expect(find.text('Nothing on the menu here yet.'), findsOneWidget);
    expect(find.byType(DishCard), findsNothing);
  });

  testWidgets('surfaces the server message on failure', (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(
        productsError: const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server. Check your connection.',
        ),
      ),
    );

    expect(
      find.text('Could not reach the server. Check your connection.'),
      findsOneWidget,
    );
    expect(find.text('Pull down to try again.'), findsOneWidget);
  });

  testWidgets('does not leak a raw error for a non-API failure',
      (tester) async {
    await pumpMenu(
      tester,
      repository: FakeMenuRepository(productsError: StateError('boom')),
    );

    expect(find.text('Could not load the menu.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('renders in dark mode without overflow', (tester) async {
    await pumpMenu(
      tester,
      theme: AppTheme.dark(),
      repository: FakeMenuRepository(
        categoryList: [buildCategory()],
        productList: [buildProduct(), buildProduct(id: 2, name: 'Pepperoni')],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DishCard), findsNWidgets(2));
  });
}

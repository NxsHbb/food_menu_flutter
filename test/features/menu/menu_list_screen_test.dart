import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/data/menu_list_controller.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/presentation/menu_list_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/category_chips.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_row.dart';

import 'fake_menu_repository.dart';

Finder chip(String label) => find.descendant(
      of: find.byType(CategoryChips),
      matching: find.text(label),
    );

/// Text inside a result row, not in the search field — which holds the same
/// string whenever the query is a dish name.
Finder rowText(String label) => find.descendant(
      of: find.byType(DishRow),
      matching: find.text(label),
    );

void main() {
  Future<FakeMenuRepository> pump(
    WidgetTester tester, {
    FakeMenuRepository? repository,
  }) async {
    final repo = repository ?? FakeMenuRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [menuRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MenuListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  List<Product> manyDishes(int count) => [
        for (var i = 1; i <= count; i++)
          buildProduct(id: i, name: 'Dish $i', price: '${100 * i}'),
      ];

  testWidgets('lists dishes with the server total, not the loaded count',
      (tester) async {
    final repo = FakeMenuRepository(productList: manyDishes(25))
      ..pageSize = 10;
    await pump(tester, repository: repo);

    // The count is the server's total, not how many are loaded or built.
    // ListView builds lazily, so the number of DishRow widgets in the tree
    // reflects the viewport, not the page size.
    expect(find.text('25 dishes'), findsOneWidget);
    expect(rowText('Dish 1'), findsOneWidget);
    expect(repo.pageRequests.single.page, 1);
  });

  testWidgets('singular label for a single match', (tester) async {
    await pump(
      tester,
      repository: FakeMenuRepository(productList: [buildProduct()]),
    );

    expect(find.text('1 dish'), findsOneWidget);
  });

  testWidgets('appends the next page when scrolled near the bottom',
      (tester) async {
    final repo = FakeMenuRepository(productList: manyDishes(25))
      ..pageSize = 10;
    await pump(tester, repository: repo);

    expect(repo.pageRequests.map((r) => r.page), [1]);

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 1000);
    await tester.pumpAndSettle();

    // Page 2 was requested. The count header has scrolled out of the lazy
    // list by now, so it is not assertable here.
    expect(repo.pageRequests.map((r) => r.page), containsAllInOrder([1, 2]));
  });

  testWidgets('stops requesting once the last page is in', (tester) async {
    final repo = FakeMenuRepository(productList: manyDishes(12))
      ..pageSize = 10;
    await pump(tester, repository: repo);

    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(ListView), const Offset(0, -4000), 1000);
      await tester.pumpAndSettle();
    }

    // Page 2 completes the set, so nothing should ask for page 3.
    expect(repo.pageRequests.where((r) => r.page > 2), isEmpty);
  });

  testWidgets('debounces typing into one request', (tester) async {
    final repo = FakeMenuRepository(productList: manyDishes(5));
    await pump(tester, repository: repo);
    repo.pageRequests.clear();

    await tester.enterText(find.byType(TextField), 'd');
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(find.byType(TextField), 'di');
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(find.byType(TextField), 'dis');
    await tester.pump(const Duration(milliseconds: 80));

    // Still inside the debounce window.
    expect(repo.pageRequests, isEmpty);

    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();

    expect(repo.pageRequests, hasLength(1));
    expect(repo.pageRequests.single.search, 'dis');
  });

  testWidgets('clearing the field searches again immediately', (tester) async {
    final repo = FakeMenuRepository(productList: manyDishes(3));
    await pump(tester, repository: repo);

    await tester.enterText(find.byType(TextField), 'Dish 1');
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();
    repo.pageRequests.clear();

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.pumpAndSettle();

    // No debounce wait: clearing should feel instant.
    expect(repo.pageRequests, isNotEmpty);
    expect(repo.pageRequests.last.search, '');
  });

  testWidgets('a new search replaces results rather than appending',
      (tester) async {
    final repo = FakeMenuRepository(productList: manyDishes(25))
      ..pageSize = 10;
    await pump(tester, repository: repo);

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 1000);
    await tester.pumpAndSettle();
    expect(repo.pageRequests.map((r) => r.page), containsAllInOrder([1, 2]));

    await tester.enterText(find.byType(TextField), 'Dish 7');
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();

    // One match, and the accumulated pages are gone rather than appended to.
    expect(find.text('1 dish'), findsOneWidget);
    expect(rowText('Dish 7'), findsOneWidget);
    expect(find.byType(DishRow), findsOneWidget);
  });

  testWidgets('shows the query back in the empty state', (tester) async {
    await pump(
      tester,
      repository: FakeMenuRepository(productList: [buildProduct(name: 'Latte')]),
    );

    await tester.enterText(find.byType(TextField), 'sushi');
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();

    expect(find.text('No dishes match “sushi”.'), findsOneWidget);
  });

  testWidgets('category selection scopes the request', (tester) async {
    final repo = await pump(
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
          buildProduct(id: 2, name: 'Latte'),
        ],
      ),
    );

    expect(find.byType(DishRow), findsNWidgets(2));

    await tester.tap(chip('Pizza'));
    await tester.pumpAndSettle();

    expect(repo.pageRequests.last.categoryId, 10);
    expect(find.byType(DishRow), findsOneWidget);
    expect(find.text('Margherita'), findsOneWidget);
  });

  testWidgets('strips HTML from the description', (tester) async {
    final product = Product.fromJson({
      'id': 1,
      'name': 'Garlic Bread',
      'prices': const {
        'price': '450',
        'currency_minor_unit': 2,
        'currency_prefix': r'$',
      },
      'short_description':
          '<p>Toasted sourdough &amp; roasted garlic &#8217;butter&#8217;</p>',
    });
    await pump(tester, repository: FakeMenuRepository(productList: [product]));

    expect(
      find.text('Toasted sourdough & roasted garlic ’butter’'),
      findsOneWidget,
    );
    expect(find.textContaining('<p>'), findsNothing);
  });

  testWidgets('keeps loaded pages when a later page fails', (tester) async {
    final repo = FakeMenuRepository(productList: manyDishes(25))
      ..pageSize = 10;
    await pump(tester, repository: repo);

    repo.productsError = const ApiException(
      failure: ApiFailure.network,
      message: 'offline',
    );
    await tester.fling(find.byType(ListView), const Offset(0, -4000), 1000);
    await tester.pumpAndSettle();

    // The first page is still on screen, with a retry offered — the list was
    // not blanked by the failure.
    expect(find.byType(DishRow), findsAtLeast(1));
    expect(find.text('Could not load more. Retry'), findsOneWidget);
  });

  testWidgets('surfaces a first-page failure', (tester) async {
    await pump(
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
  });
}

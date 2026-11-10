import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/cart/presentation/widgets/quick_add_button.dart';
import 'package:food_menu/src/features/menu/presentation/product_detail_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_row.dart';
import 'package:go_router/go_router.dart';

import '../menu/fake_menu_repository.dart';
import 'fake_cart_repository.dart';

/// Both the grid card and the list row, so neither can be wired up and the
/// other forgotten — which is exactly how the `+` was left behind by Phase 4.
enum DishWidget { card, row }

void main() {
  late FakeCartRepository repo;

  /// The dish laid out as [which] draws it, under a router that has somewhere
  /// for the dish screen to go.
  Future<void> pump(
    WidgetTester tester,
    Product product, {
    DishWidget which = DishWidget.card,
    Duration delay = Duration.zero,
  }) async {
    repo = FakeCartRepository(delay: delay);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 300,
                child: switch (which) {
                  DishWidget.card => DishCard(product: product, onTap: () {}),
                  DishWidget.row => DishRow(product: product, onTap: () {}),
                },
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: 'dish/:id',
              name: ProductDetailScreen.routeName,
              builder: (_, state) => Scaffold(
                body: Text('dish screen ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cartRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapPlus(WidgetTester tester) async {
    await tester.tap(find.byType(QuickAddButton));
    await tester.pumpAndSettle();
  }

  for (final which in DishWidget.values) {
    group('on a dish ${which.name}', () {
      testWidgets('the + adds the dish to the cart', (tester) async {
        await pump(tester, buildProduct(id: 14, name: 'Margherita'),
            which: which);

        await tapPlus(tester);

        expect(repo.calls, contains('add 14 x1'));
        // Nothing is said: the cart bar is the confirmation, and a snackbar
        // would cover it — see `QuickAddButton`.
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('a dish needing choices opens the dish screen instead',
          (tester) async {
        await pump(
          tester,
          buildProduct(id: 25, name: 'Fresh Lemonade', requiresChoices: true),
          which: which,
        );

        await tapPlus(tester);

        expect(find.text('dish screen 25'), findsOneWidget);
        // Not even attempted: the dish declared itself, so there is nothing to
        // learn from a refusal.
        expect(repo.calls.where((c) => c.startsWith('add')), isEmpty);
      });

      testWidgets('a variable dish opens the dish screen too', (tester) async {
        await pump(
          tester,
          buildProduct(id: 27, name: 'Build Your Pizza', hasOptions: true),
          which: which,
        );

        await tapPlus(tester);

        expect(find.text('dish screen 27'), findsOneWidget);
        expect(repo.calls.where((c) => c.startsWith('add')), isEmpty);
      });

      testWidgets('a sold-out dish opens the dish screen, which says so',
          (tester) async {
        await pump(
          tester,
          buildProduct(id: 31, name: 'Sold Out Special', inStock: false),
          which: which,
        );

        await tapPlus(tester);

        expect(find.text('dish screen 31'), findsOneWidget);
        expect(repo.calls.where((c) => c.startsWith('add')), isEmpty);
      });
    });
  }

  testWidgets('the + spins while the add is in flight', (tester) async {
    await pump(
      tester,
      buildProduct(id: 14),
      delay: const Duration(milliseconds: 60),
    );

    await tester.tap(find.byType(QuickAddButton));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(QuickAddButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.add), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('a second tap while it spins adds nothing more', (tester) async {
    await pump(
      tester,
      buildProduct(id: 14),
      delay: const Duration(milliseconds: 60),
    );

    await tester.tap(find.byType(QuickAddButton));
    await tester.pump();
    // The guard is the controller's, but this is the tap that would otherwise
    // reach it: a disabled InkWell swallows the gesture rather than queueing.
    await tester.tap(find.byType(QuickAddButton));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c.startsWith('add')), ['add 14 x1']);
  });

  testWidgets('a refusal is shown in the server\'s own words', (tester) async {
    await pump(tester, buildProduct(id: 14));
    repo.failNextWrite = const ApiException(
      failure: ApiFailure.http,
      message: 'Sorry, this item is out of stock.',
      statusCode: 400,
    );

    await tapPlus(tester);

    expect(find.text('Sorry, this item is out of stock.'), findsOneWidget);
  });

  testWidgets('an add-on refusal lands on the dish screen', (tester) async {
    // A store whose plugin predates `requires_choices`: the dish looked
    // addable, and only the server knew otherwise.
    await pump(tester, buildProduct(id: 25, name: 'Fresh Lemonade'));
    repo.failNextWrite = const ApiException(
      failure: ApiFailure.http,
      message: 'Please choose an option for Choose your size.',
      statusCode: 400,
      code: 'fmp_app_addon_required',
    );

    await tapPlus(tester);

    expect(find.text('dish screen 25'), findsOneWidget);
    expect(find.text('This dish needs a few choices first.'), findsOneWidget);
  });

  testWidgets('the row says "options" for a required add-on group too',
      (tester) async {
    await pump(
      tester,
      buildProduct(id: 25, name: 'Fresh Lemonade', requiresChoices: true),
      which: DishWidget.row,
    );

    // The design's own label for "this tap leads to choices". Before the
    // plugin published the flag it appeared on variable dishes only.
    expect(find.text('options'), findsOneWidget);
  });
}

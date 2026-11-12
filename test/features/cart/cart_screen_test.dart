import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_controller.dart';
import 'package:food_menu/src/features/cart/presentation/cart_screen.dart';
import 'package:food_menu/src/features/cart/presentation/widgets/cart_line_row.dart';

import 'fake_cart_repository.dart';

void main() {
  late FakeCartRepository repo;

  Future<void> pump(
    WidgetTester tester, {
    Cart? cart,
    Object? error,
    ThemeData? theme,
  }) async {
    repo = FakeCartRepository(cart: cart)..failNext = error;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(repo),
          // See task 8.7: the cart bar now asks whether the store takes
          // orders, and the real request's timeout outlives the tree.
          orderingDisabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: const CartScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('an empty cart', () {
    testWidgets('offers the menu rather than a blank screen', (tester) async {
      await pump(tester);

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse menu'), findsOneWidget);
      // Nothing to clear, so the action is not offered.
      expect(find.text('Clear all'), findsNothing);
    });
  });

  group('a cart with lines', () {
    testWidgets('lists each line with its total', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      expect(find.byType(CartLineRow), findsNWidgets(2));
      expect(find.text('Fresh Lemonade'), findsOneWidget);
      expect(find.text('Margherita'), findsOneWidget);
      expect(find.text(r'$14.50'), findsOneWidget);
      expect(find.text(r'$9.00'), findsOneWidget);
    });

    testWidgets('counts units, not rows', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      expect(find.text('3 items'), findsOneWidget);
    });

    testWidgets('shows what was chosen under the dish name', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      expect(
        find.text('Medium 12" · Mushrooms ×2 · No ice please'),
        findsOneWidget,
      );
    });

    testWidgets('totals the cart, with the amount due last', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      // Subtotal, total and the checkout button all read $23.50 — this store
      // charges no tax and the cart has no discount, so they agree.
      expect(find.text(r'$23.50'), findsNWidgets(3));
      // Nothing is invented: with no tax and no shipping chosen, neither row
      // appears at all.
      expect(find.text('Tax'), findsNothing);
      expect(find.text('Delivery'), findsNothing);
    });
  });

  group('changing a line', () {
    testWidgets('the plus sends a higher quantity and redraws', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      await tester.tap(find.bySemanticsLabel('One more').first);
      await tester.pumpAndSettle();

      expect(repo.calls.last, startsWith('update '));
      expect(repo.calls.last, endsWith(' 3'));
      // 3 × $7.25
      expect(find.text(r'$21.75'), findsOneWidget);
    });

    testWidgets('the bin removes the line', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(repo.calls.last, startsWith('remove '));
      expect(find.byType(CartLineRow), findsOneWidget);
      expect(find.text('Fresh Lemonade'), findsNothing);
    });

    testWidgets('stepping below the minimum removes the line', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      // The Margherita is a single, so one step down is a removal.
      await tester.tap(find.bySemanticsLabel('Remove').first);
      await tester.pumpAndSettle();

      expect(repo.calls.last, startsWith('remove '));
      expect(find.byType(CartLineRow), findsOneWidget);
    });

    testWidgets('a refused change says why and keeps the cart', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      repo.failNext = const ApiException(
        failure: ApiFailure.http,
        message: 'Fresh Lemonade is out of stock.',
        statusCode: 409,
      );

      await tester.tap(find.bySemanticsLabel('One more').first);
      await tester.pumpAndSettle();

      expect(find.text('Fresh Lemonade is out of stock.'), findsOneWidget);
      expect(find.byType(CartLineRow), findsNWidgets(2));
    });
  });

  group('clearing', () {
    testWidgets('asks before emptying', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('Empty your cart?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(repo.calls, isNot(contains('clear')));
      expect(find.byType(CartLineRow), findsNWidgets(2));
    });

    testWidgets('confirming empties it', (tester) async {
      await pump(tester, cart: cartFromFixture('cart_with_addons'));

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear all').last);
      await tester.pumpAndSettle();

      expect(repo.calls, contains('clear'));
      expect(find.text('Your cart is empty'), findsOneWidget);
    });
  });

  group('server notices', () {
    testWidgets('a cart error is shown above the lines', (tester) async {
      final base = cartFromFixture('cart_with_addons');
      await pump(
        tester,
        cart: Cart(
          items: base.items,
          itemsCount: base.itemsCount,
          totals: base.totals,
          needsPayment: base.needsPayment,
          needsShipping: base.needsShipping,
          shippingPackages: base.shippingPackages,
          paymentMethods: base.paymentMethods,
          errors: const ['Margherita has been removed from your cart.'],
        ),
      );

      expect(
        find.text('Margherita has been removed from your cart.'),
        findsOneWidget,
      );
    });
  });

  group('a failed load', () {
    testWidgets('offers a retry that re-reads', (tester) async {
      await pump(
        tester,
        error: const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the store.',
        ),
      );

      expect(find.text('Could not reach the store.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);
    });
  });

  testWidgets('renders in dark mode without error', (tester) async {
    await pump(
      tester,
      cart: cartFromFixture('cart_with_addons'),
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CartLineRow), findsNWidgets(2));
  });
}

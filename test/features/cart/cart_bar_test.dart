import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_controller.dart';
import 'package:food_menu/src/features/cart/data/cart_controller.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/cart/presentation/cart_screen.dart';
import 'package:food_menu/src/features/cart/presentation/widgets/cart_bar.dart';
import 'package:go_router/go_router.dart';

import 'fake_cart_repository.dart';

void main() {
  Future<void> pump(WidgetTester tester, {Cart? cart, ThemeData? theme}) async {
    final router = GoRouter(
      initialLocation: '/menu',
      routes: [
        GoRoute(
          path: '/menu',
          // The screen underneath must fill, as `navigationShell` does in
          // the real shell — a Stack sized to its largest child would put the
          // bar somewhere nothing can tap.
          builder: (_, _) => const Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: Center(child: Text('menu'))),
                Positioned(left: 0, right: 0, bottom: 0, child: CartBar()),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/cart',
          name: CartScreen.routeName,
          builder: (_, _) => const Scaffold(body: Text('the cart screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The cart bar asks whether this store takes orders at all
          // (task 8.7). Pinned so these tests do not fire the real
          // order-types request, whose timeout outlives the tree.
          orderingDisabledProvider.overrideWithValue(false),
          cartRepositoryProvider.overrideWithValue(
            FakeCartRepository(cart: cart),
          ),
        ],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stays out of the way when the cart is empty', (tester) async {
    await pump(tester);

    expect(find.text('View cart'), findsNothing);
  });

  testWidgets('shows the unit count and the subtotal', (tester) async {
    await pump(tester, cart: cartFromFixture('cart_with_addons'));

    expect(find.text('View cart'), findsOneWidget);
    // Units, not rows: two lines, three units.
    expect(find.text('3'), findsOneWidget);
    expect(find.text(r'$23.50'), findsOneWidget);
  });

  testWidgets('tapping it opens the cart', (tester) async {
    await pump(tester, cart: cartFromFixture('cart_with_addons'));

    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();

    expect(find.text('the cart screen'), findsOneWidget);
  });

  test('reserves room only while it is showing', () async {
    final container = ProviderContainer(
      overrides: [
        // The cart bar asks whether this store takes orders at all
        // (task 8.7). Pinned so these tests do not fire the real
        // order-types request, whose timeout outlives the tree.
        orderingDisabledProvider.overrideWithValue(false),
        cartRepositoryProvider.overrideWithValue(
          FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(cartBarInsetProvider), 0);

    await container.read(cartControllerProvider.future);
    expect(container.read(cartBarInsetProvider), CartBar.reservedSpace);

    await container.read(cartControllerProvider.notifier).clear();
    expect(container.read(cartBarInsetProvider), 0);
  });

  testWidgets('renders in dark mode without error', (tester) async {
    await pump(
      tester,
      cart: cartFromFixture('cart_with_addons'),
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('View cart'), findsOneWidget);
  });
}

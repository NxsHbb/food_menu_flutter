import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/app.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_controller.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/menu/data/addons_repository.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';

import 'features/auth/fake_auth_repository.dart';
import 'features/cart/fake_cart_repository.dart';
import 'features/orders/fake_orders_repository.dart';
import 'features/menu/fake_addons_repository.dart';
import 'features/menu/fake_banner_repository.dart';
import 'features/menu/fake_menu_repository.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {Cart? cart}) async {
    await tester.pumpWidget(
      ProviderScope(
        // The menu screen is real now, so the shell tests would otherwise
        // reach for the network.
        overrides: [
          // The cart bar asks whether this store takes orders at all
          // (task 8.7). Pinned so these tests do not fire the real
          // order-types request, whose timeout outlives the tree.
          orderingDisabledProvider.overrideWithValue(false),
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(
              categoryList: [buildCategory()],
              productList: [buildProduct()],
            ),
          ),
          bannerRepositoryProvider.overrideWithValue(FakeBannerRepository()),
          // The cart and the dish screen are both real now, so the shell
          // tests would otherwise reach for the network.
          cartRepositoryProvider.overrideWithValue(
            FakeCartRepository(cart: cart),
          ),
          addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
          // The orders tab reads its history now, so without this it would
          // spin forever on a request that never answers and `pumpAndSettle`
          // would time out.
          ordersRepositoryProvider.overrideWithValue(FakeOrdersRepository()),
          // Without this the account tab would wait forever on a keychain read
          // that never answers under the test binding, and `pumpAndSettle`
          // would time out on its spinner.
          tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        ],
        child: const FoodMenuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the menu tab', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('What are you craving?'), findsOneWidget);
  });

  testWidgets('bottom navigation reaches every top-level destination', (
    tester,
  ) async {
    await pumpApp(tester);

    for (final label in ['Cart', 'Orders', 'Account']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('a dish opens full screen, without the tab bar', (tester) async {
    await pumpApp(tester);

    // The design shows the tab bar only on home, menu, cart, orders, account
    // and wishlist — not on a dish, which is a full-screen view with its own
    // close button. The route therefore sits outside the shell.
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Margherita').first);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('closing a dish returns to the menu with its tab bar', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Margherita').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('What are you craving?'), findsOneWidget);
  });

  testWidgets('each shell branch keeps its own state', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('What are you craving?'), findsOneWidget);
  });

  group('the cart in the shell', () {
    testWidgets('an empty cart puts nothing in the way', (tester) async {
      await pumpApp(tester);

      expect(find.text('View cart'), findsNothing);
      // The Badge widget is always in the tree; what matters is that it is
      // not showing a count.
      expect(
        tester
            .widgetList<Badge>(find.byType(Badge))
            .any((b) => b.isLabelVisible),
        isFalse,
      );
    });

    testWidgets('a filled cart badges the tab and floats a bar over the menu', (
      tester,
    ) async {
      await pumpApp(tester, cart: cartFromFixture('cart_with_addons'));

      expect(find.text('View cart'), findsOneWidget);
      // Three units across two lines.
      expect(find.widgetWithText(Badge, '3'), findsOneWidget);
    });

    testWidgets('the bar belongs to the menu, not to every tab', (
      tester,
    ) async {
      await pumpApp(tester, cart: cartFromFixture('cart_with_addons'));

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('View cart'), findsNothing);
      // The badge stays, because it is part of the tab bar itself.
      expect(find.widgetWithText(Badge, '3'), findsOneWidget);
    });

    testWidgets('the bar leads to the cart tab', (tester) async {
      await pumpApp(tester, cart: cartFromFixture('cart_with_addons'));

      await tester.tap(find.text('View cart'));
      await tester.pumpAndSettle();

      expect(find.text('My cart'), findsOneWidget);
    });
  });
}

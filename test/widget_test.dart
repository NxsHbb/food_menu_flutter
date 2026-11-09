import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/app.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/menu/data/addons_repository.dart';

import 'features/auth/fake_auth_repository.dart';
import 'features/cart/fake_cart_repository.dart';
import 'features/menu/fake_addons_repository.dart';
import 'features/menu/fake_banner_repository.dart';
import 'features/menu/fake_menu_repository.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // The menu screen is real now, so the shell tests would otherwise
        // reach for the network.
        overrides: [
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(
              categoryList: [buildCategory()],
              productList: [buildProduct()],
            ),
          ),
          bannerRepositoryProvider.overrideWithValue(FakeBannerRepository()),
          // The cart and the dish screen are both real now, so the shell
          // tests would otherwise reach for the network.
          cartRepositoryProvider.overrideWithValue(FakeCartRepository()),
          addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
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

  testWidgets('bottom navigation reaches every top-level destination',
      (tester) async {
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

  testWidgets('closing a dish returns to the menu with its tab bar',
      (tester) async {
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
}

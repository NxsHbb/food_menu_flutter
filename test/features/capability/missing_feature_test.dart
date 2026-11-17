import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/capability/capability_probe.dart';
import 'package:food_menu/src/core/capability/plugin_route.dart';
import 'package:food_menu/src/core/capability/store_capabilities.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/account/presentation/account_screen.dart';
import 'package:food_menu/src/features/account/presentation/widgets/account_row.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/presentation/login_screen.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_controller.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';
import 'package:food_menu/src/features/orders/data/order_history_controller.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/presentation/orders_screen.dart';
import 'package:food_menu/src/features/orders/presentation/widgets/order_row.dart';
import 'package:food_menu/src/features/orders/presentation/widgets/reorder_button.dart';
import 'package:food_menu/src/features/wishlist/presentation/widgets/wishlist_heart.dart';

import '../../core/capability/capability_scope.dart';
import '../auth/fake_auth_repository.dart';
import '../menu/fake_menu_repository.dart';
import '../orders/fake_orders_repository.dart';

/// Task 14.7: a missing endpoint hides a feature rather than failing.
///
/// Every case here is a real store. [releasedProStore] is the route list read
/// off `radiustheme.net/demos/food-menu` on 2026-11-17 — five `app/*` routes
/// out of 27 — and before this task the app put an error in front of the
/// customer for each of the other 22.
void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    required StoreCapabilities store,
    List<Object> extra = const [],
    bool signedIn = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        capabilitiesProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        ...extra.cast(),
      ],
    );
    addTearDown(container.dispose);

    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
    await tester.pumpAndSettle();

    return container;
  }

  group('the wishlist heart', () {
    final dish = buildProduct(id: 26, name: 'Iced Latte', price: '450');

    testWidgets('is drawn on a store that has a wishlist', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SizedBox(
            width: 200,
            child: DishCard(product: dish, onTap: () {}),
          ),
        ),
        store: newProStore,
      );

      expect(find.byType(WishlistHeart), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    testWidgets('and is gone where the plugin has no wishlist route',
        (tester) async {
      // It sits on every card, every row and the dish screen, so leaving it
      // would be the most-seen broken thing in the app.
      await pump(
        tester,
        Scaffold(
          body: SizedBox(
            width: 200,
            child: DishCard(product: dish, onTap: () {}),
          ),
        ),
        store: releasedProStore,
      );

      expect(find.byType(WishlistHeart), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });
  });

  group('the account screen', () {
    testWidgets('offers every row on the newest Pro', (tester) async {
      await pump(
        tester,
        const AccountScreen(),
        store: newProStore,
        signedIn: true,
      );

      for (final label in const [
        'My orders',
        'Wishlist',
        'Saved addresses',
        'Change password',
        'Change email',
        'Delete account',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('and only what the released Pro can do', (tester) async {
      await pump(
        tester,
        const AccountScreen(),
        store: releasedProStore,
        signedIn: true,
      );

      for (final label in const [
        'My orders',
        'Wishlist',
        'Saved addresses',
        'Change password',
        'Change email',
        'Delete account',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }

      // Not an empty card where each one was, either: an `AccountRowCard` with
      // no rows is a stray white bar that reads as a failed load.
      expect(find.byType(AccountRowCard), findsNothing);
      // The profile and log out are still there, because they still work.
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('a store with no accounts does not offer sign-in',
        (tester) async {
      await pump(
        tester,
        const AccountScreen(),
        store: StoreCapabilities.absent,
      );

      expect(find.text('Sign in'), findsNothing);
      expect(
        find.text('This restaurant does not use accounts in the app.'),
        findsOneWidget,
      );
    });

    testWidgets('and one with accounts does', (tester) async {
      await pump(tester, const AccountScreen(), store: releasedProStore);

      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('sign-in', () {
    testWidgets('hides the password reset the store cannot perform',
        (tester) async {
      // The released Pro has login and register and neither reset route, so
      // this button led to a form that could only fail.
      await pump(tester, const LoginScreen(), store: releasedProStore);

      expect(find.text('Forgot your password?'), findsNothing);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets('and offers it where both routes exist', (tester) async {
      await pump(tester, const LoginScreen(), store: newProStore);

      expect(find.text('Forgot your password?'), findsOneWidget);
    });
  });

  group('order history', () {
    testWidgets('says so plainly, before asking anyone to sign in',
        (tester) async {
      // Asking a customer to sign in to see a list that cannot exist is the
      // worse of the two lies, so this takes precedence.
      await pump(tester, const OrdersScreen(), store: releasedProStore);

      expect(find.text('No order history here'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('and makes no request for it', (tester) async {
      final repo = FakeOrdersRepository();

      final container = await pump(
        tester,
        const OrdersScreen(),
        store: releasedProStore,
        extra: [ordersRepositoryProvider.overrideWithValue(repo)],
        signedIn: true,
      );
      await container.read(orderHistoryControllerProvider.future);

      expect(repo.historyCalls, isEmpty);
    });
  });

  group('reorder', () {
    final order = summaryFixture(id: 412, status: 'completed', isActive: false);

    testWidgets('the row keeps Details and drops the dead half',
        (tester) async {
      await pump(
        tester,
        Scaffold(body: OrderRow(order: order, onTap: () {})),
        store: releasedProStore,
      );

      expect(find.byType(ReorderButton), findsNothing);
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('and offers both where the route exists', (tester) async {
      await pump(
        tester,
        Scaffold(body: OrderRow(order: order, onTap: () {})),
        store: newProStore,
      );

      expect(find.byType(ReorderButton), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });
  });

  group('ordering itself', () {
    test('a store with no order-type, slot or gateway route is a showcase', () {
      // The same answer task 8.7 gives a display-only store, reached without
      // three failing requests on the way to it.
      final container = ProviderContainer(
        overrides: [capabilitiesProvider.overrideWithValue(releasedProStore)],
      );
      addTearDown(container.dispose);

      expect(container.read(orderingDisabledProvider), isTrue);
    });

    test('and one that has them is not', () {
      final container = ProviderContainer(
        overrides: [capabilitiesProvider.overrideWithValue(newProStore)],
      );
      addTearDown(container.dispose);

      expect(container.read(orderingDisabledProvider), isFalse);
    });

    test('nor is a store the app could not ask', () {
      // A tunnel is not a closed restaurant.
      final container = ProviderContainer(
        overrides: [capabilitiesProvider.overrideWithValue(anyStore)],
      );
      addTearDown(container.dispose);

      expect(container.read(orderingDisabledProvider), isFalse);
    });

    test('one missing route of the three is enough', () {
      final container = ProviderContainer(
        overrides: [
          capabilitiesProvider.overrideWithValue(
            newProStore.ruleOut(PluginRoute.slots),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(orderingDisabledProvider), isTrue);
    });
  });
}

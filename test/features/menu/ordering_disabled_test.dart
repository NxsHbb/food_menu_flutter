import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/cart/presentation/widgets/cart_bar.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_controller.dart';
import 'package:food_menu/src/features/fulfilment/domain/order_types.dart';
import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/presentation/menu_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/category_chips.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';

import '../cart/fake_cart_repository.dart';
import 'fake_banner_repository.dart';
import 'fake_menu_repository.dart';

/// Task 8.7: a store running Food Menu as a showcase menu cannot be ordered
/// from, and the app has to say so rather than draw an empty menu.
void main() {
  ApiException failure(String? code) => ApiException(
        failure: ApiFailure.http,
        message: 'nope',
        statusCode: 403,
        code: code,
      );

  group('the provider reads the order-types failure', () {
    test('true for the plugin\'s own refusal', () async {
      final container = ProviderContainer(
        overrides: [
          orderTypesProvider.overrideWith(
            (ref) => Future.error(failure('fmp_ordering_disabled')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(orderTypesProvider.future),
        throwsA(isA<ApiException>()),
      );

      expect(container.read(orderingDisabledProvider), isTrue);
    });

    test('false for any other failure, so a tunnel is not a closed shop',
        () async {
      final container = ProviderContainer(
        overrides: [
          orderTypesProvider.overrideWith(
            (ref) => Future.error(failure('rest_no_route')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(orderTypesProvider.future),
        throwsA(isA<ApiException>()),
      );

      expect(container.read(orderingDisabledProvider), isFalse);
    });

    test('false while it is still loading', () {
      final container = ProviderContainer(
        overrides: [
          orderTypesProvider.overrideWith((ref) => Completer<OrderTypes>().future),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(orderingDisabledProvider), isFalse);
    });
  });

  testWidgets('the menu is replaced, not left empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // With dishes to show, so this proves they are **withheld** rather
          // than merely absent.
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(
              productList: [buildProduct(id: 1, name: 'Margherita')],
            ),
          ),
          bannerRepositoryProvider.overrideWithValue(FakeBannerRepository()),
          orderingDisabledProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const MenuScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not taking online orders'), findsOneWidget);

    // Everything below the header is about ordering. Leaving the dishes and
    // the chips up would offer an "Add" the server refuses.
    expect(find.byType(DishCard), findsNothing);
    expect(find.byType(CategoryChips), findsNothing);
    expect(find.text('Nothing on the menu here yet.'), findsNothing);
  });

  testWidgets('the cart bar does not invite a tap it cannot honour',
      (tester) async {
    // A real showcase store never fills a cart, but one that *switches* into
    // showcase mode leaves its customers holding them. Found on the device:
    // the panel drew correctly and the bar sat on top of it offering $13.00.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(
            FakeCartRepository(cart: cartFromFixture('cart_with_item')),
          ),
          orderingDisabledProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CartBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View cart'), findsNothing);
  });

  testWidgets('and still shows it on a store that takes orders',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(
            FakeCartRepository(cart: cartFromFixture('cart_with_item')),
          ),
          orderingDisabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CartBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View cart'), findsOneWidget);
  });

  testWidgets('an ordinary store still gets its menu', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(
              productList: [buildProduct(id: 1, name: 'Margherita')],
            ),
          ),
          bannerRepositoryProvider.overrideWithValue(FakeBannerRepository()),
          orderingDisabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const MenuScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not taking online orders'), findsNothing);
    expect(find.byType(DishCard), findsWidgets);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/address/data/address_repository.dart';
import 'package:food_menu/src/features/address/presentation/address_form_screen.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/presentation/login_screen.dart';
import 'package:food_menu/src/features/branch/data/branch_repository.dart';
import 'package:food_menu/src/features/branch/data/branch_store.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/checkout/data/checkout_repository.dart';
import 'package:food_menu/src/features/checkout/data/payment_repository.dart';
import 'package:food_menu/src/features/checkout/presentation/checkout_screen.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_repository.dart';
import 'package:go_router/go_router.dart';

import '../address/fake_address_repository.dart';
import '../auth/fake_auth_repository.dart';
import '../branch/fake_branch_repository.dart';
import '../cart/fake_cart_repository.dart';
import '../fulfilment/fake_fulfilment_repository.dart';
import 'fake_checkout_repository.dart';
import 'fake_payment_repository.dart';

export '../address/fake_address_repository.dart';
export '../auth/fake_auth_repository.dart';
export '../branch/fake_branch_repository.dart';
export '../cart/fake_cart_repository.dart';
export '../fulfilment/fake_fulfilment_repository.dart';
export 'fake_checkout_repository.dart';
export 'fake_payment_repository.dart';

/// Everything the checkout reads, faked.
///
/// The screen sits over five features — fulfilment, the cart, the address
/// book, branches and auth — so a harness is the only way to keep a test
/// about one of them readable. Shared with the fulfilment tests, which drive
/// their section through this same screen.
class CheckoutHarness {
  CheckoutHarness({
    FakeFulfilmentRepository? fulfilment,
    FakeCartRepository? cart,
    FakeAddressRepository? addresses,
    FakeBranchRepository? branches,
    FakeCheckoutRepository? checkout,
    FakePaymentRepository? payment,
  })  : fulfilment = fulfilment ?? FakeFulfilmentRepository(),
        cart = cart ?? FakeCartRepository(cart: cartFromFixture('cart_with_item')),
        addresses = addresses ??
            FakeAddressRepository(book: [buildAddress(isDefault: true)]),
        branches = branches ?? FakeBranchRepository(),
        checkout = checkout ?? FakeCheckoutRepository(),
        payment = payment ?? FakePaymentRepository();

  final FakeFulfilmentRepository fulfilment;
  final FakeCartRepository cart;
  final FakeAddressRepository addresses;
  final FakeBranchRepository branches;
  final FakeCheckoutRepository checkout;
  final FakePaymentRepository payment;
  final FakeBranchStore branchStore = FakeBranchStore();
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeTokenStore tokens = FakeTokenStore();

  /// Where the address form landed, so a test can prove the row leads to it
  /// without pulling the whole account shell into the router.
  bool addressFormOpened = false;

  late ProviderContainer container;

  /// [size] is **logical** pixels. The default is a real phone's width —
  /// where layout bugs live — over a tall viewport, so the cards below the
  /// fold are built and can be asserted on: the checkout is a `ListView` and
  /// at a real 844dp height its lower sections are never constructed.
  Future<void> pump(
    WidgetTester tester, {
    bool signedIn = true,
    Size size = const Size(390, 2400),
    double pixelRatio = 1,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        fulfilmentRepositoryProvider.overrideWithValue(fulfilment),
        cartRepositoryProvider.overrideWithValue(cart),
        addressRepositoryProvider.overrideWithValue(addresses),
        branchRepositoryProvider.overrideWithValue(branches),
        checkoutRepositoryProvider.overrideWithValue(checkout),
        paymentRepositoryProvider.overrideWithValue(payment),
        branchStoreProvider.overrideWithValue(branchStore),
        authRepositoryProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);

    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
    }

    final router = GoRouter(
      initialLocation: CheckoutScreen.routePath,
      routes: [
        GoRoute(
          path: CheckoutScreen.routePath,
          name: CheckoutScreen.routeName,
          builder: (_, _) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/cart',
          name: 'cart',
          builder: (_, _) => const Scaffold(body: Text('Cart')),
        ),
        // The order lands the customer back on the menu until task 6.4.
        GoRoute(
          path: '/menu',
          name: 'menu',
          builder: (_, _) => const Scaffold(body: Text('Menu')),
        ),
        GoRoute(
          path: LoginScreen.routePath,
          name: LoginScreen.routeName,
          builder: (_, _) => const LoginScreen(),
        ),
        GoRoute(
          path: '/addresses/new',
          name: AddressFormScreen.newRouteName,
          builder: (_, _) {
            addressFormOpened = true;
            return const Scaffold(body: Text('Address form'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

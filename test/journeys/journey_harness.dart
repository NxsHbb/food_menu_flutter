import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/app.dart';
import 'package:food_menu/src/core/network/store_session_store.dart';
import 'package:food_menu/src/features/account/data/profile_repository.dart';
import 'package:food_menu/src/features/address/data/address_repository.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/domain/auth_session.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/branch/data/branch_repository.dart';
import 'package:food_menu/src/features/branch/data/branch_store.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/checkout/data/checkout_repository.dart';
import 'package:food_menu/src/features/checkout/data/payment_repository.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_repository.dart';
import 'package:food_menu/src/features/menu/data/addons_repository.dart';
import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/data/reviews_repository.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_repository.dart';

import '../core/network/fake_store_session_store.dart';
import '../features/account/fake_profile_repository.dart';
import '../features/address/fake_address_repository.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/branch/fake_branch_repository.dart';
import '../features/cart/fake_cart_repository.dart';
import '../features/checkout/fake_checkout_repository.dart';
import '../features/checkout/fake_payment_repository.dart';
import '../features/fulfilment/fake_fulfilment_repository.dart';
import '../features/menu/fake_addons_repository.dart';
import '../features/menu/fake_banner_repository.dart';
import '../features/menu/fake_menu_repository.dart';
import '../features/menu/fake_reviews_repository.dart';
import '../features/orders/fake_orders_repository.dart';
import '../features/wishlist/fake_wishlist_repository.dart';

export '../features/address/fake_address_repository.dart';
export '../features/auth/fake_auth_repository.dart';
export '../features/branch/fake_branch_repository.dart';
export '../features/cart/fake_cart_repository.dart';
export '../features/checkout/fake_checkout_repository.dart';
export '../features/checkout/fake_payment_repository.dart';
export '../features/fulfilment/fake_fulfilment_repository.dart';
export '../features/menu/fake_addons_repository.dart';
export '../features/menu/fake_menu_repository.dart';
export '../features/orders/fake_orders_repository.dart';

/// The ids the captured fixtures use, so a journey names a dish rather than a
/// number.
///
/// Both come out of `cart_with_addons.json`: the one dish on that store with
/// add-on groups, and one without. Keeping the journeys on these two is what
/// lets the dish screen, the cart and the checkout all be checked against the
/// *same* captured response.
const lemonadeId = 25;
const margheritaId = 14;

/// `testWidgets` for a journey: the body runs under [JourneyHarness.run], so
/// the one framework assertion that navigating a riverpod app provokes is
/// filtered and every other error still fails the test.
///
/// Journeys use this instead of `testWidgets` so the filter is not something
/// each new one has to remember.
void journeyTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) => JourneyHarness.run(() => body(tester)));
}

/// The whole app, every repository faked.
///
/// The single-screen tests pump one screen with a stub for whatever it leads
/// to, which is right for asking what that screen draws — but it means no
/// test proves two real screens connect. This pumps [FoodMenuApp] itself, so
/// the router, the shell's tabs and every provider are the ones that ship,
/// and a journey walks the app the way a customer does.
///
/// Prefer a single-screen test. Reach for this only when the behaviour under
/// test *is* the handoff — what one screen gives the next.
class JourneyHarness {
  JourneyHarness({
    FakeMenuRepository? menu,
    FakeAddonsRepository? addons,
    FakeCartRepository? cart,
    FakeFulfilmentRepository? fulfilment,
    FakeCheckoutRepository? checkout,
    FakePaymentRepository? payment,
    FakeOrdersRepository? orders,
    FakeAddressRepository? addresses,
    FakeBranchRepository? branches,
    AuthSession? session,
  })  : menu = menu ??
            (FakeMenuRepository(
              categoryList: [buildCategory()],
              productList: [
                // $3.25, and the store asks a required question about it, so
                // the + opens the dish screen rather than adding blind.
                buildProduct(
                  id: lemonadeId,
                  name: 'Fresh Lemonade',
                  price: '325',
                  requiresChoices: true,
                ),
                buildProduct(id: margheritaId, name: 'Margherita', price: '900'),
              ],
            )),
        addons = addons ??
            FakeAddonsRepository(
              byProduct: {lemonadeId: addonsFromFixture('product_addons')},
            ),
        // Empty on purpose: a journey that starts with a full cart has
        // skipped the half of the handoff that fills it.
        cart = cart ?? FakeCartRepository(),
        fulfilment = fulfilment ?? FakeFulfilmentRepository(),
        checkout = checkout ?? FakeCheckoutRepository(),
        payment = payment ?? FakePaymentRepository(),
        orders = orders ?? FakeOrdersRepository(),
        addresses = addresses ??
            FakeAddressRepository(book: [buildAddress(isDefault: true)]),
        branches = branches ?? FakeBranchRepository(),
        // Carries a phone number, unlike the one-screen checkout tests: those
        // type it to prove the field works, and a journey that retyped it
        // would be testing the field again rather than the handoff.
        auth = FakeAuthRepository(
          session: session ?? sessionFor(phone: '01711 000111'),
        );

  final FakeMenuRepository menu;
  final FakeAddonsRepository addons;
  final FakeCartRepository cart;
  final FakeFulfilmentRepository fulfilment;
  final FakeCheckoutRepository checkout;
  final FakePaymentRepository payment;
  final FakeOrdersRepository orders;
  final FakeAddressRepository addresses;
  final FakeBranchRepository branches;
  final FakeAuthRepository auth;

  final FakeBranchStore branchStore = FakeBranchStore();
  final FakeTokenStore tokens = FakeTokenStore();
  final FakeBannerRepository banners = FakeBannerRepository();
  final FakeReviewsRepository reviews = FakeReviewsRepository();
  final FakeProfileRepository profile = FakeProfileRepository();
  final FakeWishlistRepository wishlist = FakeWishlistRepository();
  final FakeStoreSessionStore storeSession = FakeStoreSessionStore();

  late ProviderContainer container;

  /// [size] is **logical** pixels: a real phone's width, over a viewport tall
  /// enough that the cards below the fold are built and can be tapped. The
  /// checkout is a `ListView` and at a real 844dp height its lower sections
  /// never exist.
  Future<void> pump(
    WidgetTester tester, {
    bool signedIn = true,
    Size size = const Size(390, 2400),
    double pixelRatio = 1,
  }) async {
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        menuRepositoryProvider.overrideWithValue(menu),
        addonsRepositoryProvider.overrideWithValue(addons),
        bannerRepositoryProvider.overrideWithValue(banners),
        reviewsRepositoryProvider.overrideWithValue(reviews),
        cartRepositoryProvider.overrideWithValue(cart),
        fulfilmentRepositoryProvider.overrideWithValue(fulfilment),
        checkoutRepositoryProvider.overrideWithValue(checkout),
        paymentRepositoryProvider.overrideWithValue(payment),
        ordersRepositoryProvider.overrideWithValue(orders),
        addressRepositoryProvider.overrideWithValue(addresses),
        branchRepositoryProvider.overrideWithValue(branches),
        branchStoreProvider.overrideWithValue(branchStore),
        authRepositoryProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(tokens),
        profileRepositoryProvider.overrideWithValue(profile),
        wishlistRepositoryProvider.overrideWithValue(wishlist),
        storeSessionStoreProvider.overrideWithValue(storeSession),
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
        child: const FoodMenuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }


  /// Runs a journey with one **flutter_riverpod** assertion filtered out, and
  /// nothing else.
  ///
  /// Riverpod refreshes its scope by calling `setState` on it, and twice over
  /// a journey it does that while the framework is building:
  ///
  /// * popping a route flips the `TickerMode` of the subtree underneath, and
  ///   `ConsumerStatefulElement._updateTickerMode` resumes a paused provider
  ///   subscription from inside `didUpdateWidget`. Adding to the cart is
  ///   enough to make that subscription dirty while the dish covers the menu.
  /// * `ref.watch` on a derived provider whose dependencies went dirty while
  ///   nobody was listening flushes that chain during the build that is
  ///   watching it — the checkout's header watching `slotsProvider` after the
  ///   cart changed.
  ///
  /// Both end in `_UncontrolledProviderScopeState.scheduleRefresh`, and app
  /// code cannot reach that frame: a widget of the app's own calling
  /// `setState` during build has its own `State` on the stack instead. So that
  /// frame is what is matched, and everything else is re-raised. A journey
  /// that quietly ate real errors would be worse than no journey at all.
  ///
  /// Riverpod catches these in `runBinaryGuarded` and hands them to the
  /// **zone** rather than to `FlutterError.onError`, which is why
  /// `tester.takeException` cannot reach them and this wrapper exists at all.
  /// Both are debug-only assertions. See FINDINGS.md — they are worth a task,
  /// not a workaround buried in a test.
  static Future<void> run(Future<void> Function() journey) async {
    final completer = Completer<void>();

    runZonedGuarded(() async {
      try {
        await journey();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      }
    }, (error, stack) {
      if (_isRiverpodScopeRefresh(error, stack)) return;
      if (!completer.isCompleted) completer.completeError(error, stack);
    });

    return completer.future;
  }

  static bool _isRiverpodScopeRefresh(Object error, StackTrace stack) {
    return error.toString().contains('called during build') &&
        stack.toString().contains(
              '_UncontrolledProviderScopeState.scheduleRefresh',
            );
  }

  /// Taps something that may be below the fold.
  ///
  /// A tap on an off-screen widget lands on nothing at all — quietly, which
  /// is how it ends up looking like the screen ignored it.
  Future<void> tapIn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Opens the cart tab from wherever the journey is.
  Future<void> openCartTab(WidgetTester tester) async {
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
  }
}

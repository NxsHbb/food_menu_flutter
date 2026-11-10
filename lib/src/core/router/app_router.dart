import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/change_email_screen.dart';
import '../../features/account/presentation/change_password_screen.dart';
import '../../features/account/presentation/edit_profile_screen.dart';
import '../../features/address/presentation/address_book_screen.dart';
import '../../features/address/presentation/address_form_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/cart/presentation/widgets/cart_bar.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/menu/presentation/menu_list_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/menu/presentation/product_detail_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/order_received_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/wishlist/presentation/wishlist_screen.dart';

/// The app's router.
///
/// A provider rather than a global so tests can override it and so a later
/// phase can add a redirect that depends on auth state (Phase 3) without
/// restructuring anything.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: MenuScreen.routePath,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MenuScreen.routePath,
                name: MenuScreen.routeName,
                builder: (context, state) => const MenuScreen(),
                routes: [
                  // Nested, so the bottom navigation stays visible and the
                  // menu tab keeps its own back stack.
                  GoRoute(
                    path: MenuListScreen.routePath,
                    name: MenuListScreen.routeName,
                    builder: (context, state) => const MenuListScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: CartScreen.routePath,
                name: CartScreen.routeName,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: OrdersScreen.routePath,
                name: OrdersScreen.routeName,
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  // Nested, so an order is pushed over the history and the
                  // Orders tab keeps its place when the customer comes back.
                  GoRoute(
                    path: OrderDetailScreen.routePath,
                    name: OrderDetailScreen.routeName,
                    builder: (context, state) => OrderDetailScreen(
                      orderId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AccountScreen.routePath,
                name: AccountScreen.routeName,
                builder: (context, state) => const AccountScreen(),
                routes: [
                  // Nested under Account, not a tab of its own: the design
                  // shows the tab bar on the wishlist with Account still
                  // highlighted, and reaches it from the Account row list.
                  GoRoute(
                    path: WishlistScreen.routePath,
                    name: WishlistScreen.routeName,
                    builder: (context, state) => const WishlistScreen(),
                  ),
                  GoRoute(
                    path: EditProfileScreen.routePath,
                    name: EditProfileScreen.routeName,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: ChangePasswordScreen.routePath,
                    name: ChangePasswordScreen.routeName,
                    builder: (context, state) => const ChangePasswordScreen(),
                  ),
                  GoRoute(
                    path: ChangeEmailScreen.routePath,
                    name: ChangeEmailScreen.routeName,
                    builder: (context, state) => const ChangeEmailScreen(),
                  ),
                  GoRoute(
                    path: AddressBookScreen.routePath,
                    name: AddressBookScreen.routeName,
                    builder: (context, state) => const AddressBookScreen(),
                  ),
                  // Before `:id`, or "new" would be read as an address id.
                  GoRoute(
                    path: AddressFormScreen.newRoutePath,
                    name: AddressFormScreen.newRouteName,
                    builder: (context, state) => const AddressFormScreen(),
                  ),
                  GoRoute(
                    path: AddressFormScreen.routePath,
                    name: AddressFormScreen.routeName,
                    builder: (context, state) => AddressFormScreen(
                      addressId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Outside the shell on purpose: the design shows the tab bar only on
      // home, menu, cart, orders, account and wishlist. A dish is a
      // full-screen view with its own close button, so it covers the bar.
      // Checkout is here for the same reason; order received and order
      // tracking will join it.
      // Auth sits outside the shell and is pushed, not navigated to: the
      // customer is sent here mid-task — placing an order, saving a
      // favourite — and popping returns them to it. The design has no auth
      // screens, so there is no tab or destination for them either.
      GoRoute(
        path: LoginScreen.routePath,
        name: LoginScreen.routeName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RegisterScreen.routePath,
        name: RegisterScreen.routeName,
        builder: (context, state) => const RegisterScreen(),
      ),
      // The reset pair sits beside sign-in, outside the shell, for the same
      // reason: the customer is sent here mid-task and popping returns them.
      GoRoute(
        path: ForgotPasswordScreen.routePath,
        name: ForgotPasswordScreen.routeName,
        builder: (context, state) => ForgotPasswordScreen(
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: ResetPasswordScreen.routePath,
        name: ResetPasswordScreen.routeName,
        builder: (context, state) => ResetPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: CheckoutScreen.routePath,
        name: CheckoutScreen.routeName,
        builder: (context, state) => const CheckoutScreen(),
      ),
      // Outside the shell with the checkout, and **navigated to rather than
      // pushed**: the cart it came from is gone and the checkout behind it is
      // for an order already placed, so there is nothing to go back to.
      GoRoute(
        path: OrderReceivedScreen.routePath,
        name: OrderReceivedScreen.routeName,
        builder: (context, state) => OrderReceivedScreen(
          orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: ProductDetailScreen.routePath,
        name: ProductDetailScreen.routeName,
        builder: (context, state) {
          // A non-numeric or missing id is a bad link rather than a crash:
          // the screen's own not-found state handles it.
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return ProductDetailScreen(productId: id);
        },
      ),
    ],
  );
});

/// Bottom-navigation shell around the four top-level destinations.
///
/// `StatefulShellRoute.indexedStack` keeps each tab's own navigation stack and
/// scroll position alive, which matters once the menu has a scrolled list and
/// the user dips into the cart and back.
///
/// The destinations themselves are provisional — the supplied design decides
/// the final navigation, and this exists so routing is wired and testable.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  /// The branch the floating cart bar belongs over — the menu, which is where
  /// a customer is while they fill the cart.
  static const _menuBranch = 0;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);

    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          // Floats over the menu rather than pushing it up, as the design
          // has it. The screens underneath reserve room for it through
          // `cartBarInsetProvider`, so it never covers the last dish.
          if (navigationShell.currentIndex == _menuBranch)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CartBar(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the current tab again returns it to its first screen.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          NavigationDestination(
            // The badge counts units, so three of one dish reads as three.
            icon: Badge.count(
              count: count,
              isLabelVisible: count > 0,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge.count(
              count: count,
              isLabelVisible: count > 0,
              child: const Icon(Icons.shopping_bag),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

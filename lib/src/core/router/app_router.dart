import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/menu/presentation/menu_list_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/menu/presentation/product_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';

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
                  GoRoute(
                    path: ProductDetailScreen.routePath,
                    name: ProductDetailScreen.routeName,
                    builder: (context, state) {
                      // A non-numeric or missing id is a bad link rather than
                      // a crash: the screen's own 404 handles it.
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
                      return ProductDetailScreen(productId: id);
                    },
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
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AccountScreen.routePath,
                name: AccountScreen.routeName,
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
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
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the current tab again returns it to its first screen.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

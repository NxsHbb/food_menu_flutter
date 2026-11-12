import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/menu_category.dart';
import '../../../core/store_api/models/product.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../branch/data/branch_controller.dart';
import '../../branch/presentation/widgets/branch_picker_sheet.dart';
import '../../cart/presentation/widgets/cart_bar.dart';
import '../../fulfilment/data/fulfilment_controller.dart';
import '../data/banner_repository.dart';
import '../data/menu_repository.dart';
import 'menu_list_screen.dart';
import 'product_detail_screen.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/category_chips.dart';
import 'widgets/dish_card.dart';
import 'widgets/menu_header.dart';

/// The menu landing screen: header, category chips and a dish grid.
///
/// The banner carousel between the header and the chips reads WordPress posts
/// in the `app-banners` category. It disappears entirely when nothing is
/// published there, so a site that never uses banners sees the design minus
/// one band rather than an empty slot.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  static const routePath = '/';
  static const routeName = 'menu';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannersProvider);
    final categories = ref.watch(menuCategoriesProvider);
    final products = ref.watch(menuProductsProvider);
    final selectedId = ref.watch(selectedCategoryProvider);

    final branches = ref.watch(branchesProvider).value;
    final branch = ref.watch(activeBranchProvider);

    // Task 8.7. Everything below the header is about ordering, so on a store
    // that cannot be ordered from none of it is drawn — not the chips, not
    // the banners, not an empty grid reading "Nothing on the menu here yet."
    // which blames the restaurant for having no food rather than saying it
    // does not sell online.
    final orderingOff = ref.watch(orderingDisabledProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(menuCategoriesProvider)
            ..invalidate(menuProductsProvider)
            ..invalidate(bannersProvider)
            ..invalidate(branchesProvider);
          await Future.wait([
            ref.read(menuCategoriesProvider.future),
            ref.read(menuProductsProvider.future),
            ref.read(bannersProvider.future),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MenuHeader(
                addressLabel: branches?.multiLocation == false
                    ? 'Ordering from'
                    : 'Deliver to',
                // The branch's own name once one is settled. Until the list
                // arrives the design's own placeholder stands, rather than a
                // blank line that shifts when it loads.
                address: branch?.name ?? 'Choose a branch',
                greeting: 'Welcome',
                prompt: 'What are you craving?',
                onSearchTap: () => context.goNamed(MenuListScreen.routeName),
                // Inert for a store with one location: there is nothing to
                // choose between, and a chevron that opens a list of one
                // reads as a bug.
                onAddressTap: branches?.multiLocation == false
                    ? null
                    : () => BranchPickerSheet.show(context),
              ),
            ),
            if (orderingOff)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _OrderingOff(),
              )
            else ...[
              SliverToBoxAdapter(
                child: switch (banners) {
                  // Absent while loading and when empty: a placeholder band
                  // would push the menu down for nothing.
                  AsyncData(:final value) when value.isNotEmpty => Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space16),
                    child: BannerCarousel(
                      banners: value,
                      onTap: (_) => context.goNamed(MenuListScreen.routeName),
                    ),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              SliverToBoxAdapter(
                child: switch (categories) {
                  AsyncData(:final value) when value.isNotEmpty => Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space16),
                    child: CategoryChips(
                      categories: value,
                      selectedId: selectedId,
                      onSelected: (id) => id == null
                          ? ref.read(selectedCategoryProvider.notifier).clear()
                          : ref
                                .read(selectedCategoryProvider.notifier)
                                .toggle(id),
                    ),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: _titleFor(selectedId, categories),
                  onSeeAll: () => context.goNamed(MenuListScreen.routeName),
                ),
              ),
              ..._dishSlivers(context, products),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: AppTokens.space24 + ref.watch(cartBarInsetProvider),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Popular" for the unfiltered list, otherwise the category's own name.
  String _titleFor(int? selectedId, AsyncValue<List<MenuCategory>> categories) {
    if (selectedId == null) return 'Popular';
    if (categories case AsyncData(:final value)) {
      for (final category in value) {
        if (category.id == selectedId) return category.name;
      }
    }
    return 'Dishes';
  }

  List<Widget> _dishSlivers(
    BuildContext context,
    AsyncValue<List<Product>> products,
  ) {
    return switch (products) {
      AsyncLoading() => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
      AsyncError(:final error) => [
        SliverToBoxAdapter(child: _MenuError(error: error)),
      ],
      AsyncData(:final value) when value.isEmpty => const [
        SliverToBoxAdapter(child: _EmptyMenu()),
      ],
      AsyncData(:final value) => [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              // Two columns on a phone, more on a tablet, without a
              // breakpoint table.
              maxCrossAxisExtent: 220,
              mainAxisSpacing: AppTokens.space12,
              crossAxisSpacing: AppTokens.space12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(childCount: value.length, (
              context,
              index,
            ) {
              final product = value[index];
              return DishCard(
                product: product,
                onTap: () => context.pushNamed(
                  ProductDetailScreen.routeName,
                  pathParameters: {'id': '${product.id}'},
                ),
              );
            }),
          ),
        ),
      ],
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space20,
        AppTokens.space16,
        AppTokens.space12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

/// What a showcase-menu store gets instead of a menu (task 8.7).
///
/// Written for a **customer**, not an administrator: nothing here mentions a
/// setting, a plugin or a mode, because the person reading it cannot change
/// any of them and did not ask. It says what they can do about it, which is
/// to go to the restaurant.
class _OrderingOff extends StatelessWidget {
  const _OrderingOff();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space24,
        vertical: 56,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 48, color: palette.muted),
          const SizedBox(height: AppTokens.space16),
          Text(
            'Not taking online orders',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTokens.space12),
          Text(
            'This restaurant uses the app to show its menu rather than to '
            'take orders. Give them a call or drop in to order.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Center(
        child: Text(
          'Nothing on the menu here yet.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: palette.muted),
        ),
      ),
    );
  }
}

class _MenuError extends StatelessWidget {
  const _MenuError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    // ApiException already carries a message worth showing; anything else
    // gets a generic line rather than a raw toString.
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Could not load the menu.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: palette.muted),
          const SizedBox(height: AppTokens.space12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            'Pull down to try again.',
            style: text.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

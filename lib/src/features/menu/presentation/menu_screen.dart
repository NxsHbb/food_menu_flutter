import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/menu_category.dart';
import '../../../core/store_api/models/product.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/menu_repository.dart';
import 'menu_list_screen.dart';
import 'product_detail_screen.dart';
import 'widgets/category_chips.dart';
import 'widgets/dish_card.dart';
import 'widgets/menu_header.dart';

/// The menu landing screen: header, category chips and a dish grid.
///
/// The design also shows a promotional banner carousel between the header and
/// the chips. It is **not built**, because nothing in either plugin supplies
/// banners — the content in the design is hard-coded, and one of the two
/// banners promotes a coupon code, which is a v2 feature. Needs a data source
/// before it can be real.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  static const routePath = '/';
  static const routeName = 'menu';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(menuCategoriesProvider);
    final products = ref.watch(menuProductsProvider);
    final selectedId = ref.watch(selectedCategoryProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(menuCategoriesProvider);
          ref.invalidate(menuProductsProvider);
          await Future.wait([
            ref.read(menuCategoriesProvider.future),
            ref.read(menuProductsProvider.future),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MenuHeader(
                // Placeholder copy until branches (5.5) and accounts (3.3)
                // can supply the real values.
                addressLabel: 'Deliver to',
                address: 'Choose a branch',
                greeting: 'Welcome',
                prompt: 'What are you craving?',
                onSearchTap: () =>
                    context.goNamed(MenuListScreen.routeName),
              ),
            ),
            SliverToBoxAdapter(
              child: switch (categories) {
                AsyncData(:final value) when value.isNotEmpty =>
                  Padding(
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
            const SliverToBoxAdapter(
              child: SizedBox(height: AppTokens.space24),
            ),
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
          SliverToBoxAdapter(
            child: _EmptyMenu(),
          ),
        ],
      AsyncData(:final value) => [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space16,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                // Two columns on a phone, more on a tablet, without a
                // breakpoint table.
                maxCrossAxisExtent: 220,
                mainAxisSpacing: AppTokens.space12,
                crossAxisSpacing: AppTokens.space12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: value.length,
                (context, index) {
                  final product = value[index];
                  return DishCard(
                    product: product,
                    onTap: () => context.goNamed(
                      ProductDetailScreen.routeName,
                      pathParameters: {'id': '${product.id}'},
                    ),
                    onAdd: product.canAddDirectly
                        ? () => _notYet(context, 'Add to cart')
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
    };
  }

  /// Until the screens those taps lead to exist, say so plainly rather than
  /// doing nothing, which reads as a broken tap.
  void _notYet(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is not built yet.')),
    );
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
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: palette.muted),
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

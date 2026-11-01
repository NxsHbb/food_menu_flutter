import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/menu_list_controller.dart';
import '../data/menu_repository.dart';
import 'widgets/category_chips.dart';
import 'widgets/dish_row.dart';

/// The design's Menu screen: live search, category chips and a paged list.
class MenuListScreen extends ConsumerStatefulWidget {
  const MenuListScreen({super.key});

  static const routePath = 'menu';
  static const routeName = 'menuList';

  @override
  ConsumerState<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends ConsumerState<MenuListScreen> {
  final _scroll = ScrollController();
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(menuSearchInputProvider));
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  /// Fetches the next page while the user is still some way from the bottom,
  /// so the list rarely stalls under the thumb.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) {
      ref.read(menuListControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final categories = ref.watch(menuCategoriesProvider);
    final query = ref.watch(menuQueryProvider);
    final listing = ref.watch(menuListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              0,
              AppTokens.space16,
              AppTokens.space12,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  ref.read(menuSearchInputProvider.notifier).type(value),
              decoration: InputDecoration(
                hintText: 'Search dishes, drinks…',
                prefixIcon: Icon(Icons.search, color: palette.ink, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          ref.read(menuSearchInputProvider.notifier).clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          switch (categories) {
            AsyncData(:final value) when value.isNotEmpty => CategoryChips(
                categories: value,
                selectedId: query.categoryId,
                onSelected: (id) => ref
                    .read(menuQueryProvider.notifier)
                    .toggleCategory(id),
              ),
            _ => const SizedBox.shrink(),
          },
          Expanded(child: _Results(scroll: _scroll, listing: listing)),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.scroll, required this.listing});

  final ScrollController scroll;
  final AsyncValue<MenuListState> listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final search = ref.watch(menuQueryProvider).search;

    return switch (listing) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => _Failure(error: error),
      AsyncData(:final value) when value.products.isEmpty => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Text(
              search.isEmpty
                  ? 'Nothing on the menu here yet.'
                  : 'No dishes match “$search”.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: palette.muted),
            ),
          ),
        ),
      AsyncData(:final value) => ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space12,
            AppTokens.space16,
            AppTokens.space24,
          ),
          // One header row, the dishes, then a footer when more can load.
          itemCount: value.products.length + (value.hasMore ? 2 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space2),
                child: Text(
                  // The server's total, not the number loaded so far.
                  value.total == 1 ? '1 dish' : '${value.total} dishes',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              );
            }
            final itemIndex = index - 1;
            if (itemIndex >= value.products.length) {
              return const _LoadMoreFooter();
            }
            final product = value.products[itemIndex];
            return DishRow(
              product: product,
              onTap: () => _notYet(context, product.name),
              onAdd: product.canAddDirectly
                  ? () => _notYet(context, 'Add to cart')
                  : null,
            );
          },
        ),
    };
  }

  void _notYet(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is not built yet.')),
    );
  }
}

/// Footer shown while another page loads, or offering a retry if one failed.
class _LoadMoreFooter extends ConsumerWidget {
  const _LoadMoreFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(menuLoadMoreErrorProvider);

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
          child: TextButton(
            onPressed: () {
              ref.read(menuLoadMoreErrorProvider.notifier).clear();
              ref.read(menuListControllerProvider.notifier).loadMore();
            },
            child: const Text('Could not load more. Retry'),
          ),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.space16),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final message =
        error is ApiException ? (error as ApiException).message : 'Could not load the menu.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

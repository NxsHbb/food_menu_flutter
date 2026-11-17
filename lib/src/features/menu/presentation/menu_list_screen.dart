import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../cart/presentation/widgets/cart_bar.dart';
import '../data/menu_list_controller.dart';
import '../data/menu_repository.dart';
import 'package:go_router/go_router.dart';

import 'product_detail_screen.dart';
import '../domain/category_suggestions.dart';
import 'widgets/category_chips.dart';
import 'widgets/menu_filter_sheet.dart';
import 'widgets/empty_search_result.dart';
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

  /// Leaves the search behind and browses a category instead.
  ///
  /// Clears the field's own text as well as the query: leaving "pizza" in the
  /// box while showing the Pizza category reads as the search having worked.
  void _browseCategory(int categoryId) {
    _search.clear();
    ref.read(menuSearchInputProvider.notifier).clear();
    ref.read(menuQueryProvider.notifier).browseCategory(categoryId);
    setState(() {});
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) =>
                        ref.read(menuSearchInputProvider.notifier).type(value),
                    decoration: InputDecoration(
                      hintText: 'Search dishes, drinks…',
                      prefixIcon:
                          Icon(Icons.search, color: palette.ink, size: 20),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _search.clear();
                                ref
                                    .read(menuSearchInputProvider.notifier)
                                    .clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                _FilterButton(filtered: query.isFiltered),
              ],
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
          Expanded(
            child: _Results(
              scroll: _scroll,
              listing: listing,
              onBrowseCategory: _browseCategory,
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.scroll,
    required this.listing,
    required this.onBrowseCategory,
  });

  final ScrollController scroll;
  final AsyncValue<MenuListState> listing;

  /// Switches to a category and clears the search box, including its text.
  final ValueChanged<int> onBrowseCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final search = ref.watch(menuQueryProvider).search;

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: switch (listing) {
        // **The value is matched before the state** (task 14.8), so a pull
        // refreshes the list the customer is looking at instead of replacing
        // it with a spinner. Matching `AsyncLoading` first would blank the
        // menu on every pull, since a refreshing provider is loading *and*
        // still holds its last value.
        //
        // An error is matched before the value for the opposite reason: a
        // menu that could not be reloaded should say so, and `_Failure`
        // already carries the retry that task 11.1 added.
        AsyncError(:final error) => _scrollable(_Failure(error: error)),
        AsyncValue(:final value?) when value.products.isEmpty => _scrollable(
            search.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppTokens.space24),
                    child: Text(
                      'Nothing on the menu here yet.',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: palette.muted),
                    ),
                  )
                : EmptySearchResult(
                    query: search,
                    // Matched against the categories already loaded for the
                    // chip row, so a dead-end search costs no extra request.
                    suggestions: switch (ref.watch(menuCategoriesProvider)) {
                      AsyncData(:final value) =>
                        suggestCategories(value, search),
                      _ => const [],
                    },
                    onBrowseCategory: (category) =>
                        onBrowseCategory(category.id),
                  ),
          ),
        AsyncValue(:final value?) => ListView.separated(
            controller: scroll,
            // A menu shorter than the screen still has to be pullable.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppTokens.space16,
              AppTokens.space12,
              AppTokens.space16,
              AppTokens.space24 + ref.watch(cartBarInsetProvider),
            ),
            // One header row, the dishes, then a footer when more can load.
            itemCount: value.products.length + (value.hasMore ? 2 : 1),
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTokens.space10),
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
                onTap: () => context.pushNamed(
                  ProductDetailScreen.routeName,
                  pathParameters: {'id': '${product.id}'},
                ),
              );
            },
          ),
        // The very first load, with nothing yet to pull on.
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Reloads the menu behind a pull (task 14.8).
///
/// **The chips as well as the dishes.** A store that has just added a
/// category is the commonest reason to pull at all, and a refreshed list
/// under a stale chip row is a worse answer than either on its own.
///
/// The query itself is left alone: a pull means "ask again", not "start
/// over", and clearing a customer's search or tag would discard what they
/// asked for. `MenuListController` rebuilds from whatever the query holds.
Future<void> _refresh(WidgetRef ref) async {
  ref
    ..invalidate(menuListControllerProvider)
    ..invalidate(menuCategoriesProvider);

  // Only the list is awaited. The chips are decoration beside it, and
  // holding the indicator open for a second request makes the pull feel
  // slower than the screen actually is.
  await ref.read(menuListControllerProvider.future);
}

/// Lets a screenful of nothing be pulled anyway.
///
/// A `RefreshIndicator` needs a scrollable child, and the empty, dead-end and
/// failed states are each a centred box. Without this the gesture works on a
/// full menu and does nothing on the three screens where a customer is most
/// likely to try it.
Widget _scrollable(Widget child) {
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
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

class _Failure extends ConsumerWidget {
  const _Failure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            // **The screen had no way off it.** A dropped connection left a
            // cloud icon, a sentence and nothing to tap — on the screen a
            // customer reaches by opening a category or searching, which is
            // most of the menu. The list rebuilds from its own query, so
            // invalidating the controller is the whole retry.
            const SizedBox(height: AppTokens.space16),
            OutlinedButton(
              onPressed: () => ref.invalidate(menuListControllerProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the sort-and-filter sheet, and says when something is in force.
///
/// **The dot is the whole affordance.** A filtered list looks like a short
/// menu, and a customer who forgot they set a tag has no other way to tell
/// the difference between "nothing matches" and "the store sells nothing".
class _FilterButton extends ConsumerWidget {
  const _FilterButton({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);

    return Semantics(
      button: true,
      label: filtered ? 'Sort and filter, active' : 'Sort and filter',
      child: SizedBox(
        height: 48,
        width: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: palette.field,
              borderRadius: BorderRadius.circular(AppTokens.radiusControl),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => MenuFilterSheet.show(context, ref),
                child: SizedBox(
                  height: 48,
                  width: 48,
                  child: Icon(Icons.tune, size: 20, color: palette.ink),
                ),
              ),
            ),
            if (filtered)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

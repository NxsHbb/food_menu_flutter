import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/store_api/models/product.dart';
import '../../branch/data/branch_controller.dart';
import 'menu_repository.dart';

/// How the list is ordered (task 14.5).
///
/// [storeOrder] sends **no** `orderby` at all, which is not the same as
/// picking one: it leaves the Store API on whatever the store arranged, and
/// is what the app did before this existed. Every other value is a WooCommerce
/// `orderby`, and an unknown one is a 400 rather than a quiet fallback — so
/// this enum is the only place they are spelled.
enum MenuSort {
  storeOrder(label: "The store's order"),
  priceLowHigh(label: 'Price: low to high', orderby: 'price', order: 'asc'),
  priceHighLow(label: 'Price: high to low', orderby: 'price', order: 'desc'),
  popularity(label: 'Most popular', orderby: 'popularity'),
  newest(label: 'Newest', orderby: 'date');

  const MenuSort({required this.label, this.orderby, this.order});

  final String label;

  /// Null for [storeOrder], where the parameter is omitted entirely.
  final String? orderby;

  /// WooCommerce defaults to `desc` where this is null, which is right for
  /// popularity and newest and wrong for nothing here.
  final String? order;
}

/// What the list screen is currently asking for.
class MenuQuery {
  const MenuQuery({
    this.search = '',
    this.categoryId,
    this.tagIds = const {},
    this.sort = MenuSort.storeOrder,
  });

  final String search;
  final int? categoryId;

  /// Food tags to narrow to. **The server ORs them**, so two tags widen the
  /// list rather than narrowing it — which is what a customer picking both
  /// "Vegan" and "Spicy" means, and is worth knowing before anyone assumes
  /// otherwise.
  final Set<int> tagIds;

  final MenuSort sort;

  /// True when anything beyond a search or category is in force, which is
  /// what the filter button's dot reflects.
  bool get isFiltered => tagIds.isNotEmpty || sort != MenuSort.storeOrder;

  MenuQuery copyWith({
    String? search,
    int? categoryId,
    bool clearCategory = false,
    Set<int>? tagIds,
    MenuSort? sort,
  }) {
    return MenuQuery(
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      tagIds: tagIds ?? this.tagIds,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MenuQuery &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.sort == sort &&
      // Set equality, not identity: the controller rebuilds on every query
      // change, so two equal filters must compare equal or picking the same
      // tag twice would refetch the same list.
      other.tagIds.length == tagIds.length &&
      other.tagIds.containsAll(tagIds);

  @override
  int get hashCode => Object.hash(
        search,
        categoryId,
        sort,
        Object.hashAllUnordered(tagIds),
      );
}

/// The list screen's accumulated results.
class MenuListState {
  const MenuListState({
    this.products = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<Product> products;

  /// Total matches on the server, which is what the design's count shows —
  /// not the number loaded so far.
  final int total;
  final int page;
  final bool hasMore;

  /// True while a further page is in flight, so the list can show a footer
  /// spinner without replacing what is already on screen.
  final bool loadingMore;

  MenuListState copyWith({
    List<Product>? products,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return MenuListState(
      products: products ?? this.products,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Debounce before a keystroke becomes a request.
const searchDebounce = Duration(milliseconds: 350);

/// The search box's raw text, updated on every keystroke.
class MenuSearchInput extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  /// Sets the text immediately, so the field stays responsive, and schedules
  /// the committed value separately.
  void type(String value) {
    state = value;
    _timer?.cancel();
    // Clearing the box should feel instant rather than waiting out a debounce.
    if (value.isEmpty) {
      ref.read(menuQueryProvider.notifier).setSearch('');
      return;
    }
    _timer = Timer(searchDebounce, () {
      ref.read(menuQueryProvider.notifier).setSearch(value);
    });
  }

  void clear() {
    _timer?.cancel();
    state = '';
    ref.read(menuQueryProvider.notifier).setSearch('');
  }
}

final menuSearchInputProvider =
    NotifierProvider<MenuSearchInput, String>(MenuSearchInput.new);

/// The debounced query the list actually fetches.
class MenuQueryNotifier extends Notifier<MenuQuery> {
  @override
  MenuQuery build() => const MenuQuery();

  void setSearch(String search) {
    if (state.search == search) return;
    state = state.copyWith(search: search);
  }

  /// Switches to browsing a category, abandoning the search that led here.
  ///
  /// One state change rather than two, so the list is not rebuilt twice —
  /// once for the cleared search and again for the new category.
  void browseCategory(int id) {
    state = const MenuQuery().copyWith(categoryId: id);
  }

  /// Selects a category, or clears it when the selected one is tapped again.
  void toggleCategory(int? id) {
    if (id == null || state.categoryId == id) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(categoryId: id);
    }
  }

  /// Applies the filter sheet's choices in **one** state change, so the list
  /// is fetched once rather than once per tag the customer touched.
  void applyFilters({required Set<int> tagIds, required MenuSort sort}) {
    final next = state.copyWith(tagIds: tagIds, sort: sort);
    if (next == state) return;
    state = next;
  }

  /// Drops the tags and the sort, leaving the search and category alone —
  /// those have their own visible controls and clearing them from a sheet
  /// the customer cannot see would be a surprise.
  void clearFilters() {
    applyFilters(tagIds: const {}, sort: MenuSort.storeOrder);
  }
}

final menuQueryProvider =
    NotifierProvider<MenuQueryNotifier, MenuQuery>(MenuQueryNotifier.new);

/// Loads and accumulates pages for the current [MenuQuery].
///
/// Rebuilt from scratch whenever the query changes, which is what makes a new
/// search discard the previous results rather than appending to them.
class MenuListController extends AsyncNotifier<MenuListState> {
  @override
  Future<MenuListState> build() async {
    // The branch is a cache key here too — it travels on a header, so two
    // branches produce identical-looking requests with different answers.
    ref.watch(activeBranchIdProvider);

    final query = ref.watch(menuQueryProvider);
    final page = await ref
        .watch(menuRepositoryProvider)
        .productPage(
          categoryId: query.categoryId,
          search: query.search,
          tagIds: query.tagIds,
          sort: query.sort,
          page: 1,
        );

    return MenuListState(
      products: page.items,
      total: page.total,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// Appends the next page. Safe to call repeatedly from a scroll listener:
  /// it is a no-op while one is already in flight or when the end is reached.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    final query = ref.read(menuQueryProvider);

    try {
      final next = await ref.read(menuRepositoryProvider).productPage(
            categoryId: query.categoryId,
            search: query.search,
            tagIds: query.tagIds,
            sort: query.sort,
            page: current.page + 1,
          );

      // The query may have changed while the page was in flight; dropping the
      // result is correct, because build() has already restarted the list.
      if (query != ref.read(menuQueryProvider)) return;

      state = AsyncData(
        current.copyWith(
          products: [...current.products, ...next.items],
          total: next.total,
          page: next.page,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } catch (error, stack) {
      // Keep what is on screen; surface the failure without blanking the list.
      state = AsyncData(current.copyWith(loadingMore: false));
      ref.read(menuLoadMoreErrorProvider.notifier).set(error, stack);
    }
  }
}

final menuListControllerProvider =
    AsyncNotifierProvider<MenuListController, MenuListState>(
  MenuListController.new,
);

/// The last failure from [MenuListController.loadMore], so the screen can
/// show a retry affordance at the bottom without losing the loaded pages.
class MenuLoadMoreError extends Notifier<Object?> {
  @override
  Object? build() => null;

  void set(Object error, StackTrace stack) => state = error;

  void clear() => state = null;
}

final menuLoadMoreErrorProvider =
    NotifierProvider<MenuLoadMoreError, Object?>(MenuLoadMoreError.new);

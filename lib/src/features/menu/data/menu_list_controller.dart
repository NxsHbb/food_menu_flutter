import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/store_api/models/product.dart';
import 'menu_repository.dart';

/// What the list screen is currently asking for.
class MenuQuery {
  const MenuQuery({this.search = '', this.categoryId});

  final String search;
  final int? categoryId;

  MenuQuery copyWith({String? search, int? categoryId, bool clearCategory = false}) {
    return MenuQuery(
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MenuQuery &&
      other.search == search &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(search, categoryId);
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
    final query = ref.watch(menuQueryProvider);
    final page = await ref
        .watch(menuRepositoryProvider)
        .productPage(
          categoryId: query.categoryId,
          search: query.search,
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

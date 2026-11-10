import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_controller.dart';
import '../domain/order_summary.dart';
import 'orders_repository.dart';

/// Which tab the history screen is showing.
///
/// Separate from the list itself so switching tabs rebuilds the list rather
/// than appending to it — the same shape the menu's query notifier has.
class OrderGroupNotifier extends Notifier<OrderGroup> {
  @override
  OrderGroup build() => OrderGroup.active;

  void show(OrderGroup group) {
    if (state == group) return;
    state = group;
  }
}

final orderGroupProvider =
    NotifierProvider<OrderGroupNotifier, OrderGroup>(OrderGroupNotifier.new);

/// One tab's accumulated pages.
class OrderHistoryState {
  const OrderHistoryState({
    this.orders = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<OrderSummary> orders;

  /// The server's count for this group, not the number loaded — it is what
  /// the design's "Active (N)" tab label shows.
  final int total;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  bool get isEmpty => orders.isEmpty;

  OrderHistoryState copyWith({
    List<OrderSummary>? orders,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return OrderHistoryState(
      orders: orders ?? this.orders,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Loads and accumulates pages for the selected tab.
///
/// Rebuilt from scratch when the tab changes, which is what stops Past orders
/// being appended to the Active list.
class OrderHistoryController extends AsyncNotifier<OrderHistoryState> {
  @override
  Future<OrderHistoryState> build() async {
    // Signed out is an empty history, not an error. Asking anyway would turn
    // the Orders tab into a 401 with a "Try again" that cannot work; watching
    // this instead means signing in loads the list and signing out drops it,
    // with no invalidation anywhere. The wishlist does the same.
    if (!ref.watch(isSignedInProvider)) return const OrderHistoryState();

    final group = ref.watch(orderGroupProvider);

    final page = await ref.watch(ordersRepositoryProvider).orders(
          group: group,
          page: 1,
        );

    return OrderHistoryState(
      orders: page.items,
      total: page.total,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// Appends the next page. A no-op while one is in flight or at the end, so
  /// a scroll listener can call it freely.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    final group = ref.read(orderGroupProvider);

    try {
      final next = await ref.read(ordersRepositoryProvider).orders(
            group: group,
            page: current.page + 1,
          );

      // The tab may have changed while the page was in flight. Dropping it is
      // correct: build() has already restarted the list for the new tab.
      if (group != ref.read(orderGroupProvider)) return;

      state = AsyncData(
        current.copyWith(
          orders: [...current.orders, ...next.items],
          total: next.total,
          page: next.page,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stack) {
      // Keep the pages already on screen and report the failure beneath them,
      // rather than blanking a list the customer is reading.
      state = AsyncData(current.copyWith(loadingMore: false));
      ref.read(orderHistoryLoadMoreErrorProvider.notifier).set(error, stack);
    }
  }

  /// Re-reads the current tab from page one, for pull-to-refresh.
  ///
  /// An order's status changes while the customer watches it, so this list
  /// goes stale on its own — unlike the menu, which only changes when the
  /// store changes.
  Future<void> reload() async {
    ref.read(orderHistoryLoadMoreErrorProvider.notifier).clear();
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final orderHistoryControllerProvider =
    AsyncNotifierProvider<OrderHistoryController, OrderHistoryState>(
  OrderHistoryController.new,
  // The screen offers "Try again"; a background retry would keep firing while
  // the customer reads the error, as everywhere else in the app.
  retry: (retryCount, error) => null,
);

/// The last failure from [OrderHistoryController.loadMore], so the screen can
/// offer a retry at the bottom without losing the pages above it.
class OrderHistoryLoadMoreError extends Notifier<Object?> {
  @override
  Object? build() => null;

  void set(Object error, StackTrace stack) => state = error;

  void clear() => state = null;
}

final orderHistoryLoadMoreErrorProvider =
    NotifierProvider<OrderHistoryLoadMoreError, Object?>(
  OrderHistoryLoadMoreError.new,
);

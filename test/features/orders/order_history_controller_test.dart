import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/orders/data/order_history_controller.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_orders_repository.dart';

/// Paging is tested here rather than through the screen on purpose.
///
/// A list with another page to come keeps a spinner in the tree, and
/// `pumpAndSettle` can never settle on one — so a widget test of paging has
/// to be written around its own scaffolding. The behaviour belongs to the
/// controller anyway; the screen only draws what it is given.
void main() {
  late FakeOrdersRepository repo;

  /// A signed-in container: the controller reads nothing without one, since
  /// an order history belongs to an account.
  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login(username: 'customer@foodmenu.test', password: 'pw');

    return container;
  }

  setUp(() {
    repo = FakeOrdersRepository()..pageSize = 2;
  });

  OrderHistoryController controllerOf(ProviderContainer container) =>
      container.read(orderHistoryControllerProvider.notifier);

  test('the first page is read on build', () async {
    repo.history[OrderGroup.active] = [
      for (var i = 0; i < 5; i++) summaryFixture(id: 1000 + i),
    ];
    final container = await makeContainer();

    final state = await container.read(orderHistoryControllerProvider.future);

    expect(state.orders, hasLength(2));
    // The server's count, not what was loaded — it is the tab's label.
    expect(state.total, 5);
    expect(state.hasMore, isTrue);
  });

  test('loadMore appends rather than replacing', () async {
    repo.history[OrderGroup.active] = [
      for (var i = 0; i < 5; i++) summaryFixture(id: 1000 + i),
    ];
    final container = await makeContainer();
    await container.read(orderHistoryControllerProvider.future);

    await controllerOf(container).loadMore();

    final state = container.read(orderHistoryControllerProvider).value!;
    expect(state.orders.map((o) => o.id), [1000, 1001, 1002, 1003]);
    expect(repo.historyCalls.map((c) => c.page), [1, 2]);
  });

  test('the last page stops asking', () async {
    repo.history[OrderGroup.active] = [
      summaryFixture(id: 1),
      summaryFixture(id: 2),
    ];
    final container = await makeContainer();
    await container.read(orderHistoryControllerProvider.future);

    await controllerOf(container).loadMore();
    await controllerOf(container).loadMore();

    expect(repo.historyCalls, hasLength(1));
  });

  test('a second loadMore while one is in flight is dropped', () async {
    repo = FakeOrdersRepository(delay: const Duration(milliseconds: 30))
      ..pageSize = 2;
    repo.history[OrderGroup.active] = [
      for (var i = 0; i < 6; i++) summaryFixture(id: 1000 + i),
    ];
    final container = await makeContainer();
    await container.read(orderHistoryControllerProvider.future);

    final first = controllerOf(container).loadMore();
    await controllerOf(container).loadMore();
    await first;

    // One page fetched, not two — a scroll listener fires freely and must not
    // load the same page twice.
    expect(repo.historyCalls.map((c) => c.page), [1, 2]);
  });

  test('a failed page keeps the ones already loaded', () async {
    repo.history[OrderGroup.active] = [
      for (var i = 0; i < 6; i++) summaryFixture(id: 1000 + i),
    ];
    final container = await makeContainer();
    await container.read(orderHistoryControllerProvider.future);

    repo.failNextHistory = const ApiException(
      failure: ApiFailure.network,
      message: 'Gone.',
    );
    await controllerOf(container).loadMore();

    // Blanking a list the customer is reading would be worse than the
    // failure, which is reported beneath it instead.
    final state = container.read(orderHistoryControllerProvider).value!;
    expect(state.orders, hasLength(2));
    expect(state.loadingMore, isFalse);
    expect(container.read(orderHistoryLoadMoreErrorProvider), isNotNull);
  });

  test('switching tabs starts the list again', () async {
    repo.history[OrderGroup.active] = [summaryFixture(id: 1)];
    repo.history[OrderGroup.past] = [
      summaryFixture(id: 2, isActive: false, status: 'completed'),
    ];
    final container = await makeContainer();
    await container.read(orderHistoryControllerProvider.future);

    container.read(orderGroupProvider.notifier).show(OrderGroup.past);
    final state = await container.read(orderHistoryControllerProvider.future);

    expect(state.orders.map((o) => o.id), [2]);
    expect(state.page, 1);
  });

  test('a page landing after the tab changed is dropped', () async {
    repo = FakeOrdersRepository(delay: const Duration(milliseconds: 40))
      ..pageSize = 2;
    repo.history[OrderGroup.active] = [
      for (var i = 0; i < 6; i++) summaryFixture(id: 1000 + i),
    ];
    repo.history[OrderGroup.past] = [
      summaryFixture(id: 9, isActive: false, status: 'completed'),
    ];
    final container = await makeContainer();
    await container.read(orderHistoryControllerProvider.future);

    final pending = controllerOf(container).loadMore();
    container.read(orderGroupProvider.notifier).show(OrderGroup.past);
    await pending;
    await container.read(orderHistoryControllerProvider.future);

    // The Active page must not be appended to the Past list it arrived into.
    final state = container.read(orderHistoryControllerProvider).value!;
    expect(state.orders.map((o) => o.id), [9]);
  });

  test('reload re-reads from page one and clears a stale error', () async {
    repo.history[OrderGroup.active] = [
      for (var i = 0; i < 6; i++) summaryFixture(id: 1000 + i),
    ];
    final container = await makeContainer();
    await container.read(orderHistoryControllerProvider.future);

    repo.failNextHistory = const ApiException(
      failure: ApiFailure.network,
      message: 'Gone.',
    );
    await controllerOf(container).loadMore();
    expect(container.read(orderHistoryLoadMoreErrorProvider), isNotNull);

    await controllerOf(container).reload();

    expect(container.read(orderHistoryLoadMoreErrorProvider), isNull);
    expect(repo.historyCalls.last.page, 1);
  });

  test('signed out, nothing is asked for at all', () async {
    repo.history[OrderGroup.active] = [summaryFixture()];
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(orderHistoryControllerProvider.future);

    expect(state.orders, isEmpty);
    expect(repo.historyCalls, isEmpty);
  });

  test('signing in loads the history with no invalidation anywhere', () async {
    repo.history[OrderGroup.active] = [summaryFixture(id: 1048)];
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(orderHistoryControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(username: 'customer@foodmenu.test', password: 'pw');
    final state = await container.read(orderHistoryControllerProvider.future);

    expect(state.orders.map((o) => o.id), [1048]);
  });
}

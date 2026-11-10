import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/branch/data/branch_controller.dart';
import 'package:food_menu/src/features/branch/data/branch_repository.dart';
import 'package:food_menu/src/features/branch/data/branch_store.dart';
import 'package:food_menu/src/features/branch/data/branch_switch.dart';
import 'package:food_menu/src/features/branch/domain/unserved_dish.dart';
import 'package:food_menu/src/features/cart/data/cart_controller.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';

import '../cart/fake_cart_repository.dart';
import 'fake_branch_repository.dart';

void main() {
  late FakeBranchRepository branches;
  late FakeBranchStore store;
  late FakeCartRepository cart;

  setUp(() {
    branches = FakeBranchRepository();
    store = FakeBranchStore();
    cart = FakeCartRepository(cart: cartFromFixture('cart_with_addons'));
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        branchRepositoryProvider.overrideWithValue(branches),
        branchStoreProvider.overrideWithValue(store),
        cartRepositoryProvider.overrideWithValue(cart),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// The product ids the seeded cart actually holds, so the fake can be told
  /// about one that is really there.
  Future<List<int>> cartProductIds(ProviderContainer container) async {
    final loaded = await container.read(cartControllerProvider.future);
    return loaded.items.map((item) => item.id).toList();
  }

  group('check', () {
    test('asks about every dish in the cart', () async {
      final container = makeContainer();
      final ids = await cartProductIds(container);

      await container.read(branchSwitcherProvider).check(7);

      expect(branches.unservedCalls, hasLength(1));
      expect(branches.unservedCalls.single.branchId, 7);
      expect(branches.unservedCalls.single.productIds, ids);
    });

    test('an empty cart is not worth a request', () async {
      cart = FakeCartRepository();
      final container = makeContainer();
      await container.read(cartControllerProvider.future);

      final unserved = await container.read(branchSwitcherProvider).check(7);

      expect(unserved, isEmpty);
      expect(branches.unservedCalls, isEmpty);
    });

    test('a cart that has not loaded yet is loaded, not assumed empty',
        () async {
      final container = makeContainer();
      branches.unservedByBranch[7] = const [
        UnservedDish(id: 25, name: 'Fresh Lemonade'),
      ];

      // Nothing has read the cart. Sampling its value here would answer
      // "nothing to lose" and take the dish without asking — likeliest on a
      // cold start, where the picker is opened before anything touches it.
      final unserved = await container.read(branchSwitcherProvider).check(7);

      expect(cart.calls, contains('cart'));
      expect(unserved.map((d) => d.name), ['Fresh Lemonade']);
    });

    test('a cart that will not load is treated as nothing to lose', () async {
      cart = FakeCartRepository();
      cart.failNext = const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server.',
      );
      final container = makeContainer();

      final unserved = await container.read(branchSwitcherProvider).check(7);

      expect(unserved, isEmpty);
    });

    test('names the dishes the branch will not serve', () async {
      final container = makeContainer();
      final ids = await cartProductIds(container);
      branches.unservedByBranch[7] = [
        UnservedDish(id: ids.first, name: 'Garlic Bread'),
      ];

      final unserved = await container.read(branchSwitcherProvider).check(7);

      expect(unserved.map((d) => d.name), ['Garlic Bread']);
    });

    test('a failed check lets the switch through rather than blocking it',
        () async {
      final container = makeContainer();
      await cartProductIds(container);
      branches.failNextUnserved = const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server.',
      );

      // Failing closed would strand the customer on a branch they are trying
      // to leave. The cart response flags the line and checkout refuses it,
      // so nothing incorrect gets through either way.
      final unserved = await container.read(branchSwitcherProvider).check(7);

      expect(unserved, isEmpty);
    });
  });

  group('commit', () {
    test('switches and remembers the branch', () async {
      final container = makeContainer();
      await container.read(selectedBranchProvider.future);

      await container.read(branchSwitcherProvider).commit(branchId: 7);

      expect(container.read(activeBranchIdProvider), 7);
      expect(store.writes, [7]);
    });

    test('drops the lines before switching, not after', () async {
      cart = FakeCartRepository(
        cart: cartFromFixture('cart_with_addons'),
        delay: const Duration(milliseconds: 30),
      );
      final container = makeContainer();
      await container.read(selectedBranchProvider.future);
      final loaded = await container.read(cartControllerProvider.future);
      final doomed = loaded.items.first;

      final pending = container.read(branchSwitcherProvider).commit(
        branchId: 7,
        dropping: [UnservedDish(id: doomed.id, name: doomed.name)],
      );

      // Mid-removal. The branch must still be the old one: the removal goes
      // out while it is in force, so the server is never asked anything in a
      // state it would refuse.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cart.calls, contains('remove ${doomed.key}'));
      expect(container.read(activeBranchIdProvider), isNot(7));

      await pending;

      expect(container.read(activeBranchIdProvider), 7);
    });

    test('nothing to drop means no cart request at all', () async {
      final container = makeContainer();
      await container.read(selectedBranchProvider.future);
      await container.read(cartControllerProvider.future);
      cart.calls.clear();

      await container.read(branchSwitcherProvider).commit(branchId: 7);

      expect(cart.calls, isEmpty);
    });

    test('a failed removal still switches', () async {
      final container = makeContainer();
      await container.read(selectedBranchProvider.future);
      final loaded = await container.read(cartControllerProvider.future);
      cart.failNextWrite = const ApiException(
        failure: ApiFailure.http,
        message: 'That line is gone.',
        statusCode: 404,
      );

      await container.read(branchSwitcherProvider).commit(
        branchId: 7,
        dropping: [UnservedDish(id: loaded.items.first.id, name: 'Whatever')],
      );

      // Refusing to change branch because a line would not delete strands the
      // customer; the line is flagged on the cart screen either way.
      expect(container.read(activeBranchIdProvider), 7);
    });
  });

  group('removeProducts', () {
    test('takes every line for the product, not just the first', () async {
      final container = makeContainer();
      final loaded = await container.read(cartControllerProvider.future);
      final id = loaded.items.first.id;
      // The same dish twice, which is what different add-on choices produce.
      cart.seed(withDuplicateOf(loaded, id));
      await container.read(cartControllerProvider.notifier).reload();

      await container
          .read(cartControllerProvider.notifier)
          .removeProducts({id});

      final after = container.read(cartControllerProvider).value!;
      expect(after.items.where((item) => item.id == id), isEmpty);
    });

    test('an empty set does nothing', () async {
      final container = makeContainer();
      await container.read(cartControllerProvider.future);
      cart.calls.clear();

      await container
          .read(cartControllerProvider.notifier)
          .removeProducts(const {});

      expect(cart.calls, isEmpty);
    });
  });
}

/// The cart with one of its lines repeated under a second key, standing in for
/// the same dish added twice with different add-ons.
Cart withDuplicateOf(Cart cart, int productId) {
  final original = cart.items.firstWhere((item) => item.id == productId);

  final twin = CartItem(
    key: '${original.key}-twin',
    id: original.id,
    quantity: original.quantity,
    name: original.name,
    prices: original.prices,
    totals: original.totals,
    images: original.images,
    itemData: original.itemData,
    quantityLimits: original.quantityLimits,
    shortDescription: original.shortDescription,
    addons: original.addons,
  );

  return Cart(
    items: [...cart.items, twin],
    itemsCount: cart.itemsCount + twin.quantity,
    totals: cart.totals,
    needsPayment: cart.needsPayment,
    needsShipping: cart.needsShipping,
    paymentMethods: cart.paymentMethods,
    errors: cart.errors,
  );
}

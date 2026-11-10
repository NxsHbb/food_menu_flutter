import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';
import 'package:food_menu/src/features/cart/data/cart_controller.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/cart/data/quick_add_controller.dart';

import 'fake_cart_repository.dart';

/// A plain simple dish, which is what the quick add is for.
Product dish({
  int id = 11,
  String name = 'Garlic Bread',
  bool hasOptions = false,
  bool requiresChoices = false,
  bool inStock = true,
}) {
  return Product.fromJson({
    'id': id,
    'name': name,
    'has_options': hasOptions,
    'is_in_stock': inStock,
    'prices': {'price': '450', 'regular_price': '450', 'currency_minor_unit': 2},
    if (requiresChoices)
      'extensions': {
        'food-menu-pro': {'requires_choices': true},
      },
  });
}

void main() {
  late FakeCartRepository repo;

  ProviderContainer containerWith(FakeCartRepository repository) {
    final container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => repo = FakeCartRepository());

  test('a quick add puts one in the cart', () async {
    final container = containerWith(
      FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
    );
    final notifier = container.read(quickAddControllerProvider.notifier);

    final outcome = await notifier.add(dish());

    expect(outcome, isA<QuickAddSucceeded>());
    expect(container.read(cartCountProvider), 3);
  });

  test('it asks for one, with no add-on payload', () async {
    final container = containerWith(repo);

    await container.read(quickAddControllerProvider.notifier).add(dish(id: 14));

    // The leading read is the cart controller initialising itself.
    expect(repo.calls, ['cart', 'add 14 x1']);
    // The whole point of the quick add: a dish that needs nothing chosen is
    // sent without an empty selection the server would have to interpret.
    expect(repo.addonPayloads, [isEmpty]);
  });

  test('the dish is marked busy while the add is in flight', () async {
    final container = containerWith(
      FakeCartRepository(delay: const Duration(milliseconds: 40)),
    );
    final notifier = container.read(quickAddControllerProvider.notifier);

    final pending = notifier.add(dish(id: 14));

    expect(container.read(quickAddPendingProvider(14)), isTrue);
    // Only that dish: a busy `+` on one card must not spin on every other.
    expect(container.read(quickAddPendingProvider(15)), isFalse);

    await pending;

    expect(container.read(quickAddPendingProvider(14)), isFalse);
  });

  test('a second tap during the first is ignored', () async {
    final slow = FakeCartRepository(delay: const Duration(milliseconds: 40));
    final container = containerWith(slow);
    final notifier = container.read(quickAddControllerProvider.notifier);

    final first = notifier.add(dish(id: 14));
    final second = await notifier.add(dish(id: 14));

    expect(second, isNull);
    await first;

    // Two taps, one line. The guard is the whole reason the controller holds
    // state rather than each button holding its own flag.
    expect(
      slow.calls.where((call) => call.startsWith('add')),
      ['add 14 x1'],
    );
  });

  test('the dish is addable again once the add finishes', () async {
    final container = containerWith(repo);
    final notifier = container.read(quickAddControllerProvider.notifier);

    await notifier.add(dish(id: 14));
    await notifier.add(dish(id: 14));

    expect(repo.calls, ['cart', 'add 14 x1', 'add 14 x1']);
  });

  test('busy is cleared when the add fails', () async {
    final container = containerWith(repo);
    repo.failNextWrite = const ApiException(
      failure: ApiFailure.http,
      message: 'Sorry, this item is out of stock.',
      statusCode: 400,
    );

    await container.read(quickAddControllerProvider.notifier).add(dish(id: 14));

    // Otherwise the `+` spins for the rest of the session.
    expect(container.read(quickAddPendingProvider(14)), isFalse);
  });

  test("a refusal reports the server's own words", () async {
    final container = containerWith(repo);
    repo.failNextWrite = const ApiException(
      failure: ApiFailure.http,
      message: 'You cannot add another "Pepperoni" to your cart.',
      statusCode: 403,
      code: 'woocommerce_rest_cart_product_no_stock',
    );

    final outcome =
        await container.read(quickAddControllerProvider.notifier).add(dish());

    expect(
      outcome,
      isA<QuickAddFailed>().having(
        (f) => f.message,
        'message',
        'You cannot add another "Pepperoni" to your cart.',
      ),
    );
  });

  test('an add-on refusal asks for the dish screen instead', () async {
    final container = containerWith(repo);
    // What a store running a plugin without `requires_choices` answers: the
    // `+` looked addable, and the server knows better.
    repo.failNextWrite = const ApiException(
      failure: ApiFailure.http,
      message: 'Please choose an option for Choose your size.',
      statusCode: 400,
      code: 'fmp_app_addon_required',
    );

    final outcome = await container
        .read(quickAddControllerProvider.notifier)
        .add(dish(id: 25, name: 'Fresh Lemonade'));

    expect(
      outcome,
      isA<QuickAddNeedsChoices>()
          .having((o) => o.product.id, 'product', 25),
    );
  });

  test('every add-on refusal routes to the dish screen, not just required',
      () async {
    final container = containerWith(repo);
    repo.failNextWrite = const ApiException(
      failure: ApiFailure.http,
      message: 'Please choose one option for Choose your size.',
      statusCode: 400,
      code: 'fmp_app_addon_too_many',
    );

    final outcome =
        await container.read(quickAddControllerProvider.notifier).add(dish());

    expect(outcome, isA<QuickAddNeedsChoices>());
  });

  test('a dropped connection is a plain failure', () async {
    final container = containerWith(repo);
    repo.failNextWrite = const ApiException(
      failure: ApiFailure.network,
      message: 'Could not reach the server. Check your connection.',
    );

    final outcome =
        await container.read(quickAddControllerProvider.notifier).add(dish());

    expect(outcome, isA<QuickAddFailed>());
  });

  test('an add before the cart has loaded still goes through', () async {
    final container = containerWith(repo);

    // Nothing has read the cart yet, so the controller has no state to diff
    // the new line against.
    final outcome =
        await container.read(quickAddControllerProvider.notifier).add(dish());

    expect(outcome, isA<QuickAddSucceeded>());
  });
}

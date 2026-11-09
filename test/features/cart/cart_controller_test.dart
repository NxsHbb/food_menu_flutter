import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/cart/data/cart_controller.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';

import 'fake_cart_repository.dart';

void main() {
  late FakeCartRepository repo;

  ProviderContainer containerWith(FakeCartRepository repository) {
    final container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => repo = FakeCartRepository(cart: cartFromFixture('cart_with_addons')));

  test('the first read loads the cart', () async {
    final container = containerWith(repo);

    final cart = await container.read(cartControllerProvider.future);

    expect(cart.items, hasLength(2));
    expect(repo.calls, ['cart']);
  });

  test('the unit count is published for the badge', () async {
    final container = containerWith(repo);
    await container.read(cartControllerProvider.future);

    expect(container.read(cartCountProvider), 3);
  });

  test('the badge reads zero while the first load is in flight', () {
    final container = containerWith(
      FakeCartRepository(delay: const Duration(milliseconds: 50)),
    );
    container.read(cartControllerProvider);

    // Never a guess: a badge drawn before the server answers would be wrong
    // as often as it was right.
    expect(container.read(cartCountProvider), 0);
  });

  group('adding', () {
    test('sends the add-on payload through untouched', () async {
      final container = containerWith(repo);
      await container.read(cartControllerProvider.future);

      await container.read(cartControllerProvider.notifier).add(
        productId: 25,
        quantity: 2,
        addons: [
          {
            'group_id': '1',
            'option_ids': ['0'],
            'quantities': {'0': 2},
          },
        ],
      );

      expect(repo.calls.last, 'add 25 x2');
      expect(repo.addonPayloads.single.single['group_id'], '1');
    });

    test('a dish with no add-ons sends no extension block', () async {
      final container = containerWith(repo);
      await container.read(cartControllerProvider.future);

      await container
          .read(cartControllerProvider.notifier)
          .add(productId: 14);

      expect(repo.addonPayloads.single, isEmpty);
    });

    test('names the line the add landed on', () async {
      final empty = FakeCartRepository();
      final container = containerWith(empty);
      await container.read(cartControllerProvider.future);

      empty.seed(cartFromFixture('cart_with_addons'));
      final line = await container
          .read(cartControllerProvider.notifier)
          .add(productId: 25);

      expect(line, isNotNull);
      expect(line!.id, 25);
    });
  });

  group('quantity', () {
    test('a change goes to the server by line key, not product id', () async {
      final container = containerWith(repo);
      final cart = await container.read(cartControllerProvider.future);
      final line = cart.items.first;

      await container
          .read(cartControllerProvider.notifier)
          .setQuantity(line, 4);

      expect(repo.calls.last, 'update ${line.key} 4');
      expect(
        container.read(cartControllerProvider).value!.itemByKey(line.key)!
            .quantity,
        4,
      );
    });

    test('the same quantity is not sent at all', () async {
      final container = containerWith(repo);
      final cart = await container.read(cartControllerProvider.future);
      final line = cart.items.first;
      final before = repo.calls.length;

      await container
          .read(cartControllerProvider.notifier)
          .setQuantity(line, line.quantity);

      expect(repo.calls, hasLength(before));
    });

    test('zero removes the line instead of sending a zero quantity', () async {
      final container = containerWith(repo);
      final cart = await container.read(cartControllerProvider.future);
      final line = cart.items.first;

      await container
          .read(cartControllerProvider.notifier)
          .setQuantity(line, 0);

      expect(repo.calls.last, 'remove ${line.key}');
      expect(
        container.read(cartControllerProvider).value!.itemByKey(line.key),
        isNull,
      );
    });

    test('a request past the line maximum is clamped before it is sent',
        () async {
      final container = containerWith(repo);
      final cart = await container.read(cartControllerProvider.future);
      final line = cart.items.first;
      final max = line.quantityLimits.maximum;

      await container
          .read(cartControllerProvider.notifier)
          .setQuantity(line, max + 5);

      expect(repo.calls.last, 'update ${line.key} $max');
    });
  });

  group('failure', () {
    test('a failed change leaves the cart readable and rethrows', () async {
      final container = containerWith(repo);
      final cart = await container.read(cartControllerProvider.future);
      final line = cart.items.first;

      repo.failNext = const ApiException(failure: ApiFailure.http, message: 'Out of stock', statusCode: 409);

      await expectLater(
        container.read(cartControllerProvider.notifier).setQuantity(line, 5),
        throwsA(isA<ApiException>()),
      );

      // The cart the customer is reading must not blank out because one
      // quantity change failed.
      expect(container.read(cartControllerProvider).hasValue, isTrue);
      expect(container.read(cartControllerProvider).value!.items, hasLength(2));
    });

    test('the busy flag clears even when the request throws', () async {
      final container = containerWith(repo);
      final cart = await container.read(cartControllerProvider.future);
      final line = cart.items.first;
      final controller = container.read(cartControllerProvider.notifier);

      repo.failNext = const ApiException(failure: ApiFailure.http, message: 'nope');

      await expectLater(
        controller.setQuantity(line, 5),
        throwsA(isA<ApiException>()),
      );
      expect(controller.isPending(line.key), isFalse);
    });

    test('a failed first load surfaces as an error state', () async {
      final failing = FakeCartRepository()
        ..failNext = const ApiException(failure: ApiFailure.network, message: 'offline');
      final container = containerWith(failing);

      await expectLater(
        container.read(cartControllerProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(cartControllerProvider).hasError, isTrue);
    });
  });

  test('clearing empties the cart', () async {
    final container = containerWith(repo);
    await container.read(cartControllerProvider.future);

    await container.read(cartControllerProvider.notifier).clear();

    expect(repo.calls.last, 'clear');
    expect(container.read(cartControllerProvider).value!.isEmpty, isTrue);
    expect(container.read(cartCountProvider), 0);
  });

  test('reload re-reads the cart', () async {
    final container = containerWith(repo);
    await container.read(cartControllerProvider.future);

    await container.read(cartControllerProvider.notifier).reload();

    expect(repo.calls, ['cart', 'cart']);
  });
}

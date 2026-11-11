import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/data/reorder_controller.dart';

import '../cart/fake_cart_repository.dart';
import 'fake_orders_repository.dart';

void main() {
  group('Reorder', () {
    test('splits what can go back from what cannot', () {
      final reorder = reorderFixture(
        lines: const [
          ('Iced Latte', true, ''),
          ('Sold Out Special', false, 'out_of_stock'),
        ],
      );

      expect(reorder.available, hasLength(1));
      expect(reorder.unavailable, hasLength(1));
      expect(reorder.any, isTrue);
      // The customer is about to get part of their order, which the screen has
      // to say out loud.
      expect(reorder.all, isFalse);
    });

    test('carries the add-on payload back untouched', () {
      final line = reorderFixture().lines.single;

      // Straight from the plugin and straight to cart/add-item. The app does
      // not read inside it, so there is no second place for the add-on
      // contract to drift.
      expect(line.addons, [
        {
          'group_id': '0',
          'option_ids': ['1'],
        },
      ]);
    });

    test('names every refusal the server can give', () {
      expect(ReorderRefusal.from('gone'), ReorderRefusal.gone);
      expect(ReorderRefusal.from('out_of_stock'), ReorderRefusal.outOfStock);
      expect(
        ReorderRefusal.from('choices_not_recorded'),
        ReorderRefusal.choicesNotRecorded,
      );
      expect(
        ReorderRefusal.choicesNotRecorded.message,
        'your choices were not saved',
      );
    });

    test('an unknown refusal is still a refusal', () {
      // A newer plugin with a reason this build has never heard of must not
      // read as "available".
      expect(ReorderRefusal.from('invented_later'), ReorderRefusal.unavailable);
    });

    test('an empty payload reorders nothing', () {
      final empty = Reorder.fromJson(const {});

      expect(empty.lines, isEmpty);
      expect(empty.any, isFalse);
      expect(empty.all, isFalse);
    });
  });

  group('ReorderOutcome', () {
    test('says what happened, and counts properly', () {
      expect(
        const ReorderOutcome(added: 2, skipped: []).message,
        'Items added to cart',
      );
      expect(
        const ReorderOutcome(added: 1, skipped: []).message,
        'Item added to cart',
      );
      expect(
        const ReorderOutcome(added: 0, skipped: ['x']).message,
        'Nothing from this order could be added.',
      );
      expect(
        const ReorderOutcome(added: 2, skipped: ['x']).message,
        '2 items added. 1 could not be.',
      );
    });
  });

  group('ReorderController', () {
    late FakeOrdersRepository orders;
    late FakeCartRepository cart;
    late ProviderContainer container;

    setUp(() {
      orders = FakeOrdersRepository();
      cart = FakeCartRepository();
      container = ProviderContainer(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(orders),
          cartRepositoryProvider.overrideWithValue(cart),
        ],
      );
      addTearDown(container.dispose);
    });

    test('adds every line that can go back, with its add-ons', () async {
      final outcome =
          await container.read(reorderControllerProvider).run(1048);

      expect(orders.reorderRequested, [1048]);
      expect(outcome.added, 1);
      expect(outcome.skipped, isEmpty);
      // Added through the Store API's own route, so add-on validation, branch
      // scoping, timed products and stock all still apply.
      expect(cart.addonPayloads.single, [
        {
          'group_id': '0',
          'option_ids': ['1'],
        },
      ]);
    });

    test('names what it could not add rather than dropping it', () async {
      orders.reorderAnswer = reorderFixture(
        lines: const [
          ('Iced Latte', true, ''),
          ('Build Your Pizza', false, 'choices_not_recorded'),
        ],
      );

      final outcome =
          await container.read(reorderControllerProvider).run(1048);

      expect(outcome.added, 1);
      expect(outcome.isPartial, isTrue);
      expect(
        outcome.skipped,
        ['Build Your Pizza — your choices were not saved'],
      );
    });

    test('a line the server refuses on the way in is reported too', () async {
      // Sold out between reading the order and adding it. Some of the order is
      // already in the cart by now, so pretending otherwise would be a lie.
      cart.failNextWrite = const ApiException(
        failure: ApiFailure.http,
        message: 'Out of stock',
        statusCode: 400,
      );

      final outcome =
          await container.read(reorderControllerProvider).run(1048);

      expect(outcome.added, 0);
      expect(outcome.skipped, ['Iced Latte — could not be added']);
      expect(outcome.isEmpty, isTrue);
    });

    test('a failed read throws, because nothing has changed yet', () async {
      orders.failNextReorder = const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server.',
      );

      await expectLater(
        container.read(reorderControllerProvider).run(1048),
        throwsA(isA<ApiException>()),
      );
      // The cart is untouched, so the screen can simply say so.
      expect(cart.addonPayloads, isEmpty);
    });
  });
}

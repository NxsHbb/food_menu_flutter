import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/cart/data/cart_controller.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_controller.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_repository.dart';

import '../cart/fake_cart_repository.dart';
import 'fake_fulfilment_repository.dart';

void main() {
  late FakeFulfilmentRepository repo;
  late FakeCartRepository cartRepo;

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [
        fulfilmentRepositoryProvider.overrideWithValue(repo),
        cartRepositoryProvider.overrideWithValue(cartRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Brings a container to where a screen starts: the store's types and the
  /// cart are in, so a slot request can be built at all. `slotsProvider` is
  /// null before that, because there is nothing to ask about yet.
  Future<ProviderContainer> ready() async {
    final container = containerWith();
    await container.read(cartControllerProvider.future);
    await container.read(orderTypesProvider.future);
    await container.read(slotsProvider.future);
    return container;
  }

  setUp(() {
    repo = FakeFulfilmentRepository();
    cartRepo = FakeCartRepository(cart: cartFromFixture('cart_with_item'));
  });

  group('which type is in force', () {
    test('the store decides before the customer has chosen', () async {
      final container = containerWith();
      await container.read(orderTypesProvider.future);

      expect(container.read(resolvedOrderTypeProvider), OrderTypeKind.delivery);
    });

    test('nothing is resolved until the store has answered', () {
      final container = containerWith();

      // A guess here would draw a toggle the store may contradict a moment
      // later.
      expect(container.read(resolvedOrderTypeProvider), isNull);
    });

    test('the customer\'s choice wins once made', () async {
      final container = containerWith();
      await container.read(orderTypesProvider.future);

      container
          .read(fulfilmentControllerProvider.notifier)
          .chooseKind(OrderTypeKind.pickup);

      expect(container.read(resolvedOrderTypeProvider), OrderTypeKind.pickup);
    });

    test('a choice the store has since switched off is dropped', () async {
      repo.types = orderTypesFromFixture('order_types');
      final container = containerWith();
      await container.read(orderTypesProvider.future);

      container
          .read(fulfilmentControllerProvider.notifier)
          .chooseKind(OrderTypeKind.pickup);

      // The store stops offering pickup while the screen is open.
      repo.types = OrderTypes.fromJson({
        'types': [
          {'type': 'pickup', 'label': 'Pickup', 'enabled': false},
          {'type': 'delivery', 'label': 'Delivery', 'enabled': true},
        ],
      });
      container.invalidate(orderTypesProvider);
      await container.read(orderTypesProvider.future);

      expect(container.read(resolvedOrderTypeProvider), OrderTypeKind.delivery);
    });
  });

  group('choosing a slot', () {
    test('the earliest open slot stands in until one is picked', () async {
      final container = await ready();

      expect(container.read(selectedSlotProvider)!.asap, isTrue);
    });

    test('a pick is honoured', () async {
      final container = await ready();
      final slots = container.read(slotsProvider).value!;
      final wanted = slots.slots.last;

      container
          .read(fulfilmentControllerProvider.notifier)
          .chooseSlot(wanted.startMinutes);

      expect(container.read(selectedSlotProvider)!.startMinutes,
          wanted.startMinutes);
    });

    test('switching type clears the slot, as the two lists are not alike',
        () async {
      final container = await ready();
      final slots = container.read(slotsProvider).value!;
      container
          .read(fulfilmentControllerProvider.notifier)
          .chooseSlot(slots.slots.last.startMinutes);

      container
          .read(fulfilmentControllerProvider.notifier)
          .chooseKind(OrderTypeKind.pickup);

      expect(container.read(fulfilmentControllerProvider).slotMinutes, isNull);
    });

    test('a slot that becomes full is given up for the next open one',
        () async {
      final container = await ready();
      // Pick the one the captured response has already filled.
      final full = slotsFromFixture('slots_pickup')
          .slots
          .firstWhere((s) => !s.available);
      container
          .read(fulfilmentControllerProvider.notifier)
          .chooseSlot(full.startMinutes);
      repo.slotsByType = {
        OrderTypeKind.delivery: slotsFromFixture('slots_pickup'),
      };
      container.invalidate(slotsProvider);
      await container.read(slotsProvider.future);

      final selected = container.read(selectedSlotProvider)!;
      expect(selected.available, isTrue);
      expect(selected.startMinutes, isNot(full.startMinutes));
    });

    test('a blocked cart leaves nothing selected rather than something unpickable',
        () async {
      repo.slotsByType = {
        OrderTypeKind.delivery: slotsFromFixture('slots_blocked'),
      };
      final container = await ready();

      expect(container.read(selectedSlotProvider), isNull);
    });
  });

  group('the slot request', () {
    test('asks for the resolved type and sends the cart with it', () async {
      final container = await ready();

      // `cart_with_item` holds one line: product 26, two units.
      expect(container.read(slotsProvider).hasValue, isTrue);
      expect(repo.calls, contains('slots delivery - 26:2'));
    });

    test('no date is sent, so the server picks the earliest it can fulfil',
        () async {
      final container = await ready();

      expect(repo.calls.last.split(' ')[2], '-');
      expect(container.read(slotsProvider).hasValue, isTrue);
    });

    test('a changed cart re-asks, because availability depends on it', () async {
      final container = await ready();
      final before = repo.calls.where((c) => c.startsWith('slots')).length;

      final cart = container.read(cartControllerProvider).value!;
      await container
          .read(cartControllerProvider.notifier)
          .setQuantity(cart.items.first, 5);
      await container.read(slotsProvider.future);

      final after = repo.calls.where((c) => c.startsWith('slots')).toList();
      expect(after, hasLength(before + 1));
      expect(after.last, 'slots delivery - 26:5');
    });

    test('an empty cart sends no items at all', () async {
      cartRepo = FakeCartRepository();
      final container = await ready();

      expect(repo.calls.last, 'slots delivery - -');
      expect(container.read(slotsProvider).hasValue, isTrue);
    });

    test('items are encoded in a stable order', () {
      expect(
        FulfilmentRepository.encodeItems({17: 1, 42: 2}),
        FulfilmentRepository.encodeItems({42: 2, 17: 1}),
      );
      expect(FulfilmentRepository.encodeItems({42: 2, 17: 1}), '17:1,42:2');
    });

    test('a zero or negative quantity is left out', () {
      expect(FulfilmentRepository.encodeItems({42: 0, 17: 1}), '17:1');
    });

    test('one cart asks the server once, not twice', () async {
      // The request is keyed by value for this reason: watching the type, the
      // date and the cart separately inside the future had it rebuild after
      // its own await and fetch the same slots again.
      final container = await ready();

      expect(
        repo.calls.where((c) => c.startsWith('slots')),
        hasLength(1),
      );
      expect(container.read(slotRequestProvider), isNotNull);
    });

    test('an identical request is not re-fetched', () async {
      final container = await ready();
      final before = container.read(slotRequestProvider);

      // Choosing the same type again changes nothing, so neither should the key.
      container
          .read(fulfilmentControllerProvider.notifier)
          .chooseKind(OrderTypeKind.delivery);

      expect(container.read(slotRequestProvider), before);
      expect(repo.calls.where((c) => c.startsWith('slots')), hasLength(1));
    });
  });

  group('failures', () {
    test('a failed order-types read surfaces, and resolves nothing', () async {
      repo.failNext = const ApiException(failure: ApiFailure.network, message: 'nope');
      final container = containerWith();

      await expectLater(
        container.read(orderTypesProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(resolvedOrderTypeProvider), isNull);
    });

    test('a failed slot read does not take the type choice down with it',
        () async {
      final container = containerWith();
      await container.read(orderTypesProvider.future);
      repo.failNextSlots = const ApiException(failure: ApiFailure.network, message: 'no times');

      await expectLater(
        container.read(slotsProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(resolvedOrderTypeProvider), OrderTypeKind.delivery);
      expect(container.read(selectedSlotProvider), isNull);
    });
  });
}

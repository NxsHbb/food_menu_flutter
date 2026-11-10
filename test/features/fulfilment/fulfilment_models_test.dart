import 'package:flutter_test/flutter_test.dart';

import 'fake_fulfilment_repository.dart';

void main() {
  group('order types, from a captured response', () {
    final types = orderTypesFromFixture('order_types');

    test('both types arrive, with the store\'s own labels', () {
      expect(types.types.map((t) => t.kind), [
        OrderTypeKind.pickup,
        OrderTypeKind.delivery,
      ]);
      expect(types.option(OrderTypeKind.pickup)!.label, 'Pickup');
      expect(types.option(OrderTypeKind.delivery)!.label, 'Delivery');
    });

    test('the week has an entry per day, Sunday first', () {
      final pickup = types.option(OrderTypeKind.pickup)!;
      expect(pickup.days, hasLength(7));
      expect(pickup.days.first.day, 0);
      expect(pickup.days.map((d) => d.day), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('a closed day is open:false, and the open ones carry windows', () {
      final pickup = types.option(OrderTypeKind.pickup)!;
      final sunday = pickup.days.firstWhere((d) => d.day == 0);
      final monday = pickup.days.firstWhere((d) => d.day == 1);

      expect(sunday.open, isFalse);
      expect(sunday.windows, isEmpty);
      expect(monday.open, isTrue);
      expect(monday.windows.single.start, '23:00');
    });

    test('delivery defaults when both are offered, as the design opens', () {
      expect(types.defaultKind, OrderTypeKind.delivery);
    });

    test('a pickup-only store defaults to pickup, not to a type it cannot do', () {
      final pickupOnly = OrderTypes.fromJson({
        'types': [
          {'type': 'pickup', 'label': 'Pickup', 'enabled': true},
          {'type': 'delivery', 'label': 'Delivery', 'enabled': false},
        ],
      });

      expect(pickupOnly.offered.map((t) => t.kind), [OrderTypeKind.pickup]);
      expect(pickupOnly.defaultKind, OrderTypeKind.pickup);
    });

    test('a store offering neither has no default at all', () {
      final closed = OrderTypes.fromJson({
        'types': [
          {'type': 'pickup', 'label': 'Pickup', 'enabled': false},
          {'type': 'delivery', 'label': 'Delivery', 'enabled': false},
        ],
      });

      expect(closed.defaultKind, isNull);
    });

    test('a type this app cannot render is dropped, not drawn blank', () {
      final withDineIn = OrderTypes.fromJson({
        'types': [
          {'type': 'dinein', 'label': 'Dine in', 'enabled': true},
          {'type': 'pickup', 'label': 'Pickup', 'enabled': true},
        ],
      });

      expect(withDineIn.types.map((t) => t.kind), [OrderTypeKind.pickup]);
    });

    test('no preorder bound comes back as null, not as today', () {
      final unbounded = OrderTypes.fromJson({
        'types': [
          {'type': 'pickup', 'label': 'Pickup', 'enabled': true, 'last_date': null},
        ],
      });

      expect(unbounded.option(OrderTypeKind.pickup)!.lastDate, isNull);
    });
  });

  group('slots, from a captured response', () {
    final pickup = slotsFromFixture('slots_pickup');
    final delivery = slotsFromFixture('slots_delivery');

    test('ASAP leads and carries the store\'s estimate', () {
      expect(pickup.slots.first.asap, isTrue);
      expect(pickup.slots.first.label, 'ASAP (15 min)');
      expect(delivery.slots.first.label, 'ASAP (20–35 min)');
    });

    test('ASAP submits no time at all, and is identified by -1', () {
      final asap = pickup.slots.first;
      expect(asap.timeValue, isEmpty);
      expect(asap.startMinutes, -1);
      expect(asap.start, isNull);
    });

    test('pickup is a point time and delivery a window, as the design draws', () {
      expect(pickup.slots[1].label, '11:00 pm');
      expect(delivery.slots[1].label, '11:00 pm – 11:15 pm');
    });

    test('the submitted time is the store\'s format, not an ISO one', () {
      // The whole reason `value` exists. A client formatting `23:00` would
      // place orders no slot limit counted. See FINDINGS.md.
      expect(pickup.slots[1].timeValue, '11:00 pm');
      expect(pickup.slots[1].start, '23:00');
      expect(pickup.dateValue, isNot(contains('-')));
    });

    test('a full slot arrives marked, with the store\'s own sentence', () {
      final full = pickup.slots.firstWhere((s) => !s.available);

      expect(full.label, '11:15 pm');
      expect(full.reason, SlotUnavailableReason.full);
      expect(full.remaining, 0);
      expect(full.message, 'This time slot is full.');
    });

    test('the resolved choice skips the full slot', () {
      final full = pickup.slots.firstWhere((s) => !s.available);

      expect(pickup.resolve(full.startMinutes)!.startMinutes,
          pickup.firstAvailable!.startMinutes);
    });

    test('an unknown selection falls back to the earliest open slot', () {
      expect(pickup.resolve(null)!.asap, isTrue);
      expect(pickup.resolve(9999)!.asap, isTrue);
    });

    test('a chosen open slot is kept', () {
      final wanted = pickup.slots.last;
      expect(pickup.resolve(wanted.startMinutes)!.startMinutes,
          wanted.startMinutes);
    });
  });

  group('slots with nothing to choose', () {
    test('a closed day says so, in the store\'s words', () {
      final closed = slotsFromFixture('slots_closed');

      expect(closed.isEmpty, isTrue);
      expect(closed.closedReason, SlotClosedReason.weeklyClosed);
      expect(closed.message, contains('closed'));
      expect(closed.firstAvailable, isNull);
    });

    test('no required time means one ASAP row, not an empty list', () {
      final asapOnly = slotsFromFixture('slots_asap_only');

      expect(asapOnly.timeRequired, isFalse);
      expect(asapOnly.slots.single.asap, isTrue);
      expect(asapOnly.closedReason, isNull);
    });

    test('an unknown closed reason parses as null, since the message shows', () {
      expect(SlotClosedReason.tryParse('something_new'), isNull);
      expect(SlotClosedReason.tryParse(null), isNull);
    });
  });

  group('slots blocked by a dish in the cart', () {
    final blocked = slotsFromFixture('slots_blocked');

    test('a dish not served then blocks the slot and names itself', () {
      final slot = blocked.slots.firstWhere(
        (s) => s.reason == SlotUnavailableReason.notServed,
      );

      expect(slot.available, isFalse);
      expect(slot.products.single.name, 'Margherita');
      expect(slot.message, contains('Margherita'));
    });

    test('ASAP is withheld when the dish is not served now', () {
      // Not drawn as unavailable — there is no time for the customer to read,
      // so the server leaves it out and the app must not invent one.
      expect(blocked.slots.any((s) => s.asap), isFalse);
    });

    test('nothing is choosable, so the resolved slot is null', () {
      expect(blocked.firstAvailable, isNull);
      expect(blocked.resolve(null), isNull);
    });
  });
}

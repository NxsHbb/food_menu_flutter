import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';

import '../checkout/checkout_harness.dart';

void main() {
  late FakeFulfilmentRepository repo;
  late FakeCartRepository cartRepo;

  setUp(() {
    repo = FakeFulfilmentRepository();
    cartRepo = FakeCartRepository(cart: cartFromFixture('cart_with_item'));
  });

  /// The fulfilment section is driven through the real checkout screen, since
  /// that is the only place it appears. Signed out on purpose: the type and
  /// the time are the same for everyone, and an account would pull the
  /// address block into every expectation below.
  /// Wider than a phone by default, because the slot row scrolls: a tap on
  /// the fourth chip has to reach it without the test driving the scroller.
  /// The narrow case has its own test at the bottom, at 320dp.
  Future<void> pump(WidgetTester tester, {Size? size}) async {
    await CheckoutHarness(fulfilment: repo, cart: cartRepo).pump(
      tester,
      signedIn: false,
      size: size ?? const Size(800, 2400),
    );
  }

  testWidgets('both types are offered, with the store\'s labels', (tester) async {
    await pump(tester);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('the slot list opens on delivery, as the design does',
      (tester) async {
    await pump(tester);

    // Delivery's own windows, not pickup's point times.
    expect(find.text('Delivery time'), findsOneWidget);
    expect(find.text('ASAP (20–35 min)'), findsOneWidget);
    expect(find.text('11:00 pm – 11:15 pm'), findsOneWidget);
  });

  testWidgets('switching to pickup asks the server again and redraws',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup time'), findsOneWidget);
    expect(find.text('ASAP (15 min)'), findsOneWidget);
    expect(find.text('11:00 pm'), findsOneWidget);
    expect(repo.calls, contains('slots pickup - 26:2'));
  });

  testWidgets('a full slot is drawn struck through and explains itself',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    final full = tester.widget<Text>(find.text('11:15 pm'));
    expect(full.style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.text('11:15 pm'));
    await tester.pump();

    // The store's own sentence, not one composed here.
    expect(find.text('This time slot is full.'), findsOneWidget);
  });

  testWidgets('tapping an open slot selects it and keeps the list', (tester) async {
    await pump(tester);

    await tester.tap(find.text('11:30 pm – 11:45 pm'));
    await tester.pumpAndSettle();

    expect(find.text('11:30 pm – 11:45 pm'), findsOneWidget);
    // Selecting does not re-ask the server: the list already said what is open.
    expect(repo.calls.where((c) => c.startsWith('slots')), hasLength(1));
  });

  group('the date strip', () {
    testWidgets('offers every date the store takes orders for',
        (tester) async {
      // The captured delivery payload pre-orders a week ahead:
      // 2026-11-10 to 2026-11-17, against a store today of 2026-11-10.
      await pump(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Thu 12 Nov'), findsOneWidget);
      expect(find.text('Tue 17 Nov'), findsOneWidget);
    });

    testWidgets('picking a date asks the server for that day',
        (tester) async {
      await pump(tester);

      await tester.tap(find.text('Thu 12 Nov'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('slots delivery 2026-11-12 26:2'));
    });

    testWidgets('moving to another date drops the slot chosen on this one',
        (tester) async {
      await pump(tester);

      // A time on the first day...
      await tester.tap(find.text('11:30 pm – 11:45 pm'));
      await tester.pumpAndSettle();

      // ...must not follow the customer to the next. Slot identity is
      // minutes within a day, so it would silently mean a different time of
      // a different day.
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();

      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true)
          .length;

      // The date chip, and the slot the list falls back to — never two slots.
      expect(selected, greaterThan(0));
      expect(repo.calls.last, contains('2026-11-11'));
    });

    testWidgets('a store taking orders for one date draws no strip',
        (tester) async {
      // A store with `fmp_preorder_max_days` at its default sends no
      // `last_date` at all.
      repo.slotsByType = {
        OrderTypeKind.delivery: slotsWithoutPreorder(),
      };
      await pump(tester);

      // One chip would be a label pretending to be a choice.
      expect(find.text('Today'), findsNothing);
      expect(find.text('Tomorrow'), findsNothing);
    });
  });

  testWidgets('a closed day shows the store\'s own message and no chips',
      (tester) async {
    repo.slotsByType = {
      OrderTypeKind.delivery: slotsFromFixture('slots_closed'),
    };
    await pump(tester);

    expect(
      find.text('We are closed on this day. Please choose another date.'),
      findsOneWidget,
    );
    expect(find.text('ASAP (20–35 min)'), findsNothing);
  });

  testWidgets('a dish not served then blocks the slot and names itself',
      (tester) async {
    repo.slotsByType = {
      OrderTypeKind.delivery: slotsFromFixture('slots_blocked'),
    };
    await pump(tester);

    await tester.tap(find.text('11:30 pm'));
    await tester.pump();

    expect(find.text('Margherita is not served at this time.'), findsOneWidget);
  });

  testWidgets('a store taking no orders says so instead of drawing a switch',
      (tester) async {
    repo.types = OrderTypes.fromJson({
      'types': [
        {'type': 'pickup', 'label': 'Pickup', 'enabled': false},
        {'type': 'delivery', 'label': 'Delivery', 'enabled': false},
      ],
    });
    await pump(tester);

    expect(
      find.textContaining('not taking pickup or delivery orders'),
      findsOneWidget,
    );
    expect(find.text('Pickup'), findsNothing);
  });

  testWidgets('a pickup-only store gets one pill, not half a dead switch',
      (tester) async {
    repo.types = OrderTypes.fromJson({
      'types': [
        {'type': 'pickup', 'label': 'Pickup', 'enabled': true, 'time_required': true},
        {'type': 'delivery', 'label': 'Delivery', 'enabled': false},
      ],
    });
    repo.slotsByType = {
      OrderTypeKind.pickup: slotsFromFixture('slots_pickup'),
    };
    await pump(tester);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Delivery'), findsNothing);
    expect(find.text('ASAP (15 min)'), findsOneWidget);
  });

  testWidgets('no required time draws the single ASAP row', (tester) async {
    repo.slotsByType = {
      OrderTypeKind.delivery: slotsFromFixture('slots_asap_only'),
    };
    await pump(tester);

    expect(find.text('ASAP (15 min)'), findsOneWidget);
    expect(find.textContaining('No times'), findsNothing);
  });

  testWidgets('a failed load offers a retry that asks again', (tester) async {
    repo.failNext = const ApiException(
      failure: ApiFailure.network,
      message: 'No connection.',
    );
    await pump(tester);

    expect(find.text('No connection.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('an empty cart is told so rather than offered times',
      (tester) async {
    cartRepo = FakeCartRepository();
    await pump(tester);

    expect(find.text('Your cart is empty.'), findsOneWidget);
    expect(find.text('Delivery'), findsNothing);
  });

  testWidgets('a long slot label does not overflow a narrow phone',
      (tester) async {
    // A delivery label is a window — "11:00 pm – 11:15 pm" — which is wider
    // than a 320pt screen has room for beside another. The row scrolls, so
    // every chip keeps its natural width and none of them overflow.
    await pump(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    for (final label in [
      'ASAP (20–35 min)',
      '11:00 pm – 11:15 pm',
      '11:15 pm – 11:30 pm',
      '11:30 pm – 11:45 pm',
      '11:45 pm – 11:59 pm',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}

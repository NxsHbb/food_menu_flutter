import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

/// Time slots, across the screens that decide them.
///
/// `fulfilment_controller_test.dart` already proves the controller re-asks
/// when the cart changes, and `fulfilment/checkout_screen_test.dart` proves
/// the section draws what comes back. Neither can prove the two meet: the
/// cart lives on one screen and the slot list on another, and the request
/// that joins them is built from whatever the cart happened to be when the
/// checkout opened.
void main() {
  group('the times offered follow the cart', () {
    journeyTest('the slot request carries the cart the checkout was opened on',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      );
      await harness.pump(tester);

      await harness.openCartTab(tester);
      await harness.tapIn(tester, find.text('Go to checkout'));

      // Both lines, by id and quantity, in the order the encoder fixes.
      expect(harness.fulfilment.calls.last, contains('25:2'));
      expect(harness.fulfilment.calls.last, contains('14:1'));
    });

    journeyTest('a line dropped on the cart is dropped from the next request',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      );
      await harness.pump(tester);

      await harness.openCartTab(tester);
      await harness.tapIn(tester, find.text('Go to checkout'));
      expect(harness.fulfilment.calls.last, contains('14:1'));

      // Back to the cart and remove the Margherita. Availability depends on
      // what is being ordered — a dish the store cannot make at 11pm is the
      // whole reason this request carries the items at all — so the times
      // have to be asked for again without it.
      await harness.tapIn(tester, find.byIcon(Icons.arrow_back));
      expect(find.text('My cart'), findsOneWidget);

      await harness.tapIn(tester, find.byIcon(Icons.delete_outline).last);
      await harness.tapIn(tester, find.text('Go to checkout'));

      expect(harness.fulfilment.calls.last, contains('25:2'));
      expect(harness.fulfilment.calls.last, isNot(contains('14:1')));
    });

    journeyTest('an empty cart is told so rather than offered times',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_item')),
      );
      await harness.pump(tester);

      await harness.openCartTab(tester);
      // Empty it from the cart screen, then carry on to the checkout: the
      // only route to a checkout over an empty cart, and the one a customer
      // takes by tapping Clear all and then going forward anyway.
      await harness.tapIn(tester, find.text('Clear all'));
      // The dialog's confirm carries the same words as the row that opened
      // it, so it is the later of the two.
      await harness.tapIn(tester, find.text('Clear all').last);

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Go to checkout'), findsNothing);
    });
  });

  group('the type chosen on the checkout', () {
    journeyTest('switching to pickup asks again and goes on the order',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      );
      harness.checkout.order = placedOrder(id: 60, number: '60');
      harness.orders.answer = orderFromFixture('order_pickup');
      await harness.pump(tester);

      await harness.openCartTab(tester);
      await harness.tapIn(tester, find.text('Go to checkout'));

      // Delivery leads, as the design opens, so the first ask is for that.
      expect(harness.fulfilment.calls.last, contains('delivery'));

      await harness.tapIn(tester, find.text('Pickup'));
      expect(harness.fulfilment.calls.last, contains('pickup'));

      await harness.tapIn(tester, find.text('Place order'));

      // The pickup keys carry the time, and the delivery ones go empty: the
      // schema types them all as strings and an omitted one reads as null.
      final extension = harness.checkout.lastExtension;
      expect(extension['fmp_order_time_type'], 'pickup');
      expect(extension['fmp_pickup_date'], isNotEmpty);
      expect(extension['fmp_delivery_time'], '');

      // And the order received screen names the type the store used.
      expect(find.text('Pickup'), findsWidgets);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checkout_harness.dart';

void main() {
  late FakeCartRepository cartRepo;
  late FakeFulfilmentRepository fulfilment;

  setUp(() {
    // Captured from the dev site with a Delaware zone offering two flat
    // rates: $4.95 standard and $9.95 express, standard preselected.
    cartRepo = FakeCartRepository(cart: cartFromFixture('cart_with_shipping'));
    fulfilment = FakeFulfilmentRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    await CheckoutHarness(cart: cartRepo, fulfilment: fulfilment).pump(
      tester,
      signedIn: true,
      size: const Size(800, 2400),
    );
  }

  group('the rates a store offers', () {
    test('parse off the cart, with the server marking its own', () {
      final cart = cartFromFixture('cart_with_shipping');
      final package = cart.shippingPackages.single;

      expect(cart.needsShipping, isTrue);
      expect(package.rates.map((r) => r.name), [
        'Standard delivery',
        'Express delivery',
      ]);
      expect(package.selected?.rateId, 'flat_rate:1');
      expect(package.rates.last.price.format(), r'$9.95');
    });

    test('a cart with no rates has an empty list, not a null', () {
      expect(cartFromFixture('cart_with_item').shippingPackages, isEmpty);
    });
  });

  group('the delivery method section', () {
    testWidgets('offers every rate, in the store own words', (tester) async {
      await pump(tester);

      expect(find.text('Delivery method'), findsOneWidget);
      expect(find.text('Standard delivery'), findsOneWidget);
      expect(find.text('Express delivery'), findsOneWidget);
      expect(find.text(r'$9.95'), findsOneWidget);
    });

    testWidgets('marks the one in force, and offers the rest', (tester) async {
      await pump(tester);

      // A device found the selected row drawn as the only one *without* a
      // radio, which reads as the odd one out rather than the chosen one.
      // Both rows are in the group; exactly one is selected.
      final group = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.inMutuallyExclusiveGroup == true)
          .toList();

      expect(group, hasLength(2));
      expect(group.where((s) => s.properties.selected == true), hasLength(1));
    });

    testWidgets('choosing one tells the server and moves the total',
        (tester) async {
      await pump(tester);

      await tester.tap(find.text('Express delivery'));
      await tester.pumpAndSettle();

      expect(cartRepo.calls, contains('select-rate 0 flat_rate:3'));
      // The server's answer is the new truth: $13.00 of risotto plus the
      // express rate.
      expect(find.text(r'$22.95'), findsWidgets);
    });

    testWidgets('a pickup order is not asked how it should be delivered',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Pickup'));
      await tester.pumpAndSettle();

      expect(find.text('Delivery method'), findsNothing);
      expect(find.text('Standard delivery'), findsNothing);
    });

    testWidgets('one rate is reported, not offered', (tester) async {
      cartRepo = FakeCartRepository(cart: _oneRate());
      await pump(tester);

      // Still worth drawing — the customer is being charged for it — but a
      // radio that cannot change reads as a broken control.
      expect(find.text('Standard delivery'), findsOneWidget);
      expect(find.text(r'$4.95'), findsWidgets);
      expect(find.byType(Radio<Object>), findsNothing);
    });
  });
}

/// The same cart with the express rate taken away.
Cart _oneRate() {
  final cart = cartFromFixture('cart_with_shipping');
  final package = cart.shippingPackages.single;

  return Cart(
    items: cart.items,
    itemsCount: cart.itemsCount,
    totals: cart.totals,
    needsPayment: cart.needsPayment,
    needsShipping: cart.needsShipping,
    shippingPackages: [
      ShippingPackage(
        packageId: package.packageId,
        name: package.name,
        rates: [package.rates.first],
      ),
    ],
    paymentMethods: cart.paymentMethods,
    errors: cart.errors,
  );
}

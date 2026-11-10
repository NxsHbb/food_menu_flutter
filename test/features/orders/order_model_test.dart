import 'package:flutter_test/flutter_test.dart';

import 'fake_orders_repository.dart';

void main() {
  test('reads a captured delivery order', () {
    final order = orderFromFixture('order_delivery');

    expect(order.number, '62');
    expect(order.status, 'processing');
    expect(order.statusLabel, 'Processing');
    expect(order.type, 'delivery');
    expect(order.typeLabel, 'Delivery');
    // An ASAP order stores no time at all, and the estimate is the store's.
    expect(order.time, '');
    expect(order.eta, 'ASAP (20–35 min)');
    expect(order.paymentMethodTitle, 'Cash on delivery');
    expect(order.needsPayment, isFalse);
    expect(order.canTrack, isTrue);
    expect(order.exists, isTrue);
  });

  test('reads a captured pickup order', () {
    final order = orderFromFixture('order_pickup');

    expect(order.type, 'pickup');
    // A chosen time is reported as itself, not as an estimate.
    expect(order.time, '6:45 am');
    expect(order.eta, '6:45 am');
  });

  test('money arrives in minor units, as everywhere else', () {
    // "395" is $3.95, not three hundred and ninety-five dollars.
    final order = orderFromFixture('order_delivery');

    expect(order.totals.totalPrice.format(), '\$3.95');
    expect(order.items.single.total.format(), '\$3.95');
    expect(order.totals.hasDiscount, isFalse);
  });

  test('a line keeps the add-ons the order recorded', () {
    // The order stores them as text rather than ids, which is all a receipt
    // needs and all the server can promise after a menu change.
    final order = orderFromFixture('order_delivery');

    expect(order.items.single.name, 'Iced Latte');
    expect(order.items.single.quantity, 1);
    expect(order.items.single.metaSummary, 'No thanks · No cutlery, thanks');
  });

  test('the first name is what the greeting uses', () {
    expect(orderFromFixture('order_delivery').firstName, 'Test');
  });

  test('the address is one line, skipping what is empty', () {
    final order = orderFromFixture('order_delivery');

    expect(order.addressLine, '6391 Elgin St., Celina, 10299');
  });

  test('an empty payload is an order that does not exist', () {
    final order = CustomerOrder.fromJson(const {});

    expect(order.exists, isFalse);
    expect(order.canTrack, isFalse);
    expect(order.firstName, '');
    expect(order.addressLine, '');
    expect(order.totals.totalPrice.minorUnits, 0);
  });

  test('a tracking token is absent until a status change writes one', () {
    final order = CustomerOrder.fromJson(const {
      'id': 70,
      'tracking_token': '',
    });

    expect(order.canTrack, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/checkout/domain/checkout_contact.dart';
import 'package:food_menu/src/features/checkout/domain/order_draft.dart';
import 'package:food_menu/src/features/checkout/domain/payment_method.dart';
import 'package:food_menu/src/features/checkout/domain/placed_order.dart';
import 'package:food_menu/src/features/fulfilment/domain/order_types.dart';

import '../address/fake_address_repository.dart';

void main() {
  OrderDraft draft({
    OrderTypeKind type = OrderTypeKind.delivery,
    String name = 'Test Customer',
    String dateValue = 'November 10, 2026',
    String timeValue = '6:30 am',
  }) {
    return OrderDraft(
      address: buildAddress(),
      contact: CheckoutContact(name: name, phone: '01711 000111'),
      email: 'customer@foodmenu.test',
      note: '',
      type: type,
      dateValue: dateValue,
      timeValue: timeValue,
      paymentMethod: 'cod',
      expectedTotal: '395',
    );
  }

  Map<String, dynamic> extensionOf(OrderDraft value) {
    final extensions = value.toJson()['extensions'] as Map<String, dynamic>;
    return (extensions['food-menu-pro'] as Map).cast<String, dynamic>();
  }

  group('the full name', () {
    test('splits on the first space, so a surname survives whole', () {
      expect(
        OrderDraft.splitName('Nurul Huda Chowdhury'),
        ('Nurul', 'Huda Chowdhury'),
      );
    });

    test('one word goes in the first name, not nowhere', () {
      // WooCommerce rejects an empty first name; a single-word name is a real
      // name in much of the world.
      expect(OrderDraft.splitName('Madonna'), ('Madonna', ''));
    });

    test('is trimmed at both ends and in the middle', () {
      expect(OrderDraft.splitName('  Ada   Lovelace '), ('Ada', 'Lovelace'));
    });

    test('an empty name stays empty rather than becoming a space', () {
      expect(OrderDraft.splitName('   '), ('', ''));
    });
  });

  group('the plugin extension', () {
    test('sends every registered key, every time', () {
      // The schema types them all as strings, so an omitted key arrives as
      // null and the whole request is rejected with `rest_invalid_param`.
      expect(
        extensionOf(draft()).keys,
        containsAll([
          'fmp_order_time_type',
          'fmp_pickup_date',
          'fmp_pickup_time',
          'fmp_delivery_date',
          'fmp_delivery_time',
          'fmp_dinein_date',
          'fmp_dinein_time',
          'fmp_dinein_table',
          'fmp_custom_fields',
        ]),
      );
    });

    test('puts the date and time under the chosen type', () {
      final delivery = extensionOf(draft());
      expect(delivery['fmp_delivery_date'], 'November 10, 2026');
      expect(delivery['fmp_delivery_time'], '6:30 am');
      expect(delivery['fmp_pickup_date'], '');

      final pickup = extensionOf(draft(type: OrderTypeKind.pickup));
      expect(pickup['fmp_pickup_date'], 'November 10, 2026');
      expect(pickup['fmp_pickup_time'], '6:30 am');
      expect(pickup['fmp_delivery_date'], '');
    });

    test('ASAP carries no time', () {
      // The server sends ASAP with an empty value, which the plugin reads as
      // "as soon as possible". Inventing one here would book a slot.
      expect(extensionOf(draft(timeValue: ''))['fmp_delivery_time'], '');
    });

    test('never carries a dine-in table', () {
      // The app has no dine-in screen; the keys exist only to satisfy the
      // schema.
      expect(extensionOf(draft())['fmp_dinein_table'], '');
    });
  });

  group('the addresses', () {
    test('take the checkout\'s name and phone over the saved one', () {
      final body = draft(name: 'Someone Else').toJson();
      final billing = body['billing_address'] as Map<String, dynamic>;

      expect(billing['first_name'], 'Someone');
      expect(billing['last_name'], 'Else');
      expect(billing['phone'], '01711 000111');
      // The address itself still comes from the book.
      expect(billing['address_1'], '6391 Elgin St.');
      expect(billing['state'], 'DE');
    });

    test('only billing carries the email', () {
      final body = draft().toJson();

      expect(
        (body['billing_address'] as Map)['email'],
        'customer@foodmenu.test',
      );
      expect((body['shipping_address'] as Map).containsKey('email'), isFalse);
    });

    test('shipping goes even for pickup', () {
      // WooCommerce copies billing into shipping when it is absent anyway,
      // and for a delivery order this is what the driver is given.
      final body = draft(type: OrderTypeKind.pickup).toJson();

      expect((body['shipping_address'] as Map)['address_1'], '6391 Elgin St.');
    });
  });

  group('the placed order', () {
    test('reads what the Store API answers with', () {
      final order = PlacedOrder.fromJson({
        'order_id': 56,
        'order_number': 'FM-0056',
        'order_key': 'wc_order_abc',
        'status': 'processing',
        'customer_id': 8,
        'payment_result': {
          'payment_status': 'success',
          'redirect_url': 'http://store.test/received/56',
        },
      });

      expect(order.id, 56);
      // A store running an order-number plugin prints something other than
      // the id, so this is shown and the id is not.
      expect(order.reference, 'FM-0056');
      expect(order.key, 'wc_order_abc');
      expect(order.customerId, 8);
      expect(order.payment?.isSuccess, isTrue);
      expect(order.exists, isTrue);
    });

    test('falls back to the id when the store has no order number', () {
      final order = PlacedOrder.fromJson({'order_id': 56});

      expect(order.reference, '56');
      expect(order.payment, isNull);
      expect(order.exists, isTrue);
    });

    test('an order with no id does not exist', () {
      // A 200 with `order_id: 0` is a refusal dressed as a success.
      expect(PlacedOrder.fromJson(const {}).exists, isFalse);
    });

    test('a failed payment is not a success', () {
      final order = PlacedOrder.fromJson({
        'order_id': 56,
        'payment_result': {'payment_status': 'failure'},
      });

      expect(order.payment?.isSuccess, isFalse);
    });
  });

  group('the payment methods', () {
    final mixed = PaymentMethods.fromJson(const {
      'default': 'cod',
      'methods': [
        {'id': 'bacs', 'title': 'Direct bank transfer', 'supported': false},
        {'id': 'cod', 'title': 'Cash on delivery', 'supported': true},
      ],
    });

    test('an unread cart leaves the whole list standing', () {
      // Null is "we have not asked yet", which must not be read as "nothing
      // is available" and blank the section on first paint.
      expect(mixed.offered(null), hasLength(2));
    });

    test('a cart nothing can pay for offers nothing', () {
      expect(mixed.offered(const []), isEmpty);
    });

    test('only what this cart can use', () {
      // Enabled store-wide is not the same as available for this order.
      expect(
        mixed.offered(const ['cod']).map((m) => m.id),
        ['cod'],
      );
    });

    test('resolves to the choice when the app can finish it', () {
      final chosen = mixed.resolve('cod', const ['bacs', 'cod']);
      expect(chosen?.id, 'cod');
    });

    test('never resolves to one the app cannot finish', () {
      // A tap on an unsupported row must not be able to reach an order.
      final chosen = mixed.resolve('bacs', const ['bacs', 'cod']);
      expect(chosen?.id, 'cod');
    });

    test('falls back to the store default, then to the first usable', () {
      final noDefault = PaymentMethods.fromJson(const {
        'default': '',
        'methods': [
          {'id': 'cod', 'title': 'Cash', 'supported': true},
        ],
      });

      expect(mixed.resolve(null, const ['bacs', 'cod'])?.id, 'cod');
      expect(noDefault.resolve(null, const ['cod'])?.id, 'cod');
    });

    test('is null when nothing on offer can be finished', () {
      expect(mixed.resolve('bacs', const ['bacs']), isNull);
      expect(PaymentMethods.empty.resolve(null, const ['cod']), isNull);
    });
  });
}

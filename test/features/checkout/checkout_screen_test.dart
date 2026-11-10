import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/checkout/data/checkout_controller.dart';
import 'package:food_menu/src/features/checkout/presentation/widgets/checkout_address_sheet.dart';
import 'package:food_menu/src/features/checkout/presentation/widgets/checkout_error_banner.dart';
import 'package:food_menu/src/features/checkout/presentation/widgets/checkout_total_bar.dart';

import 'checkout_harness.dart';

void main() {
  final home = buildAddress(
    id: 'addr-home',
    label: 'Home',
    isDefault: true,
  );
  final work = buildAddress(
    id: 'addr-work',
    label: 'Work',
    address1: '2118 Thornridge Cir.',
    city: 'Syracuse',
    state: 'CT',
    postcode: '35624',
    locality: 'Syracuse, Connecticut 35624',
  );

  group('the signed-in checkout', () {
    testWidgets('draws the design\'s sections', (tester) async {
      await CheckoutHarness().pump(tester);

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Deliver to · Home'), findsOneWidget);
      expect(find.text('Contact details'), findsOneWidget);
      expect(find.text('Order summary'), findsOneWidget);
      expect(find.text('Place order'), findsOneWidget);
      expect(
        find.textContaining('agree to our Terms & Conditions'),
        findsOneWidget,
      );
    });

    testWidgets('says what was chosen under the title', (tester) async {
      await CheckoutHarness().pump(tester);

      // The store's own words for both the type and the time, joined — not a
      // sentence composed here.
      expect(find.text('Delivery · ASAP (20–35 min)'), findsOneWidget);
    });

    testWidgets('fills the contact fields from the account', (tester) async {
      final harness = CheckoutHarness();
      harness.auth.session = sessionFor(
        firstName: 'Jamal',
        lastName: 'Uddin',
        phone: '01711 000111',
      );
      await harness.pump(tester);

      expect(find.text('Jamal Uddin'), findsOneWidget);
      expect(find.text('01711 000111'), findsOneWidget);
    });

    testWidgets('falls back to the address when the account has no phone',
        (tester) async {
      final harness = CheckoutHarness(
        addresses: FakeAddressRepository(
          book: [home.copyWith(phone: '01911 222333')],
        ),
      );
      await harness.pump(tester);

      expect(find.text('01911 222333'), findsOneWidget);
    });

    testWidgets('keeps what was typed outside the widget', (tester) async {
      // Task 6.5 has to come back to a checkout that still has its input, and
      // the address sheet and the address book both rebuild this screen, so
      // the value cannot live in the form's own state.
      final harness = CheckoutHarness();
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Someone Else');
      await tester.enterText(find.byType(TextFormField).at(1), '01555 111222');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Ring the bell twice',
      );
      await tester.pump();

      final details = harness.container.read(checkoutControllerProvider);
      expect(details.name, 'Someone Else');
      expect(details.phone, '01555 111222');
      expect(details.note, 'Ring the bell twice');
    });
  });

  group('the order summary', () {
    testWidgets('lists each line, its add-ons and the cart\'s own totals',
        (tester) async {
      await CheckoutHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      ).pump(tester);

      expect(find.text('2× Fresh Lemonade', findRichText: true), findsOneWidget);
      expect(find.text('1× Margherita', findRichText: true), findsOneWidget);
      // Two identical dishes with different add-ons are different orders, so
      // the choices are named rather than left to the price.
      expect(
        find.text('Medium 12" · Mushrooms ×2 · No ice please'),
        findsOneWidget,
      );
      expect(find.text('\$14.50'), findsOneWidget);
      expect(find.text('\$9.00'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
    });

    testWidgets('puts the amount due in the bar, from the cart', (tester) async {
      await CheckoutHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      ).pump(tester);

      // The subtotal says it too on this cart, so this is the bar's own copy.
      expect(
        find.descendant(
          of: find.byType(CheckoutTotalBar),
          matching: find.text('\$23.50'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('incl. fees & tax'), findsOneWidget);
    });

    testWidgets('an empty cart is told so, with nothing to place',
        (tester) async {
      await CheckoutHarness(cart: FakeCartRepository()).pump(tester);

      expect(find.text('Your cart is empty.'), findsOneWidget);
      expect(find.text('Place order'), findsNothing);
      expect(find.text('Order summary'), findsNothing);
    });
  });

  group('the delivery address', () {
    testWidgets('shows the default one, and the sheet switches it',
        (tester) async {
      await CheckoutHarness(
        addresses: FakeAddressRepository(book: [home, work]),
      ).pump(tester);

      expect(find.text('6391 Elgin St.'), findsOneWidget);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(CheckoutAddressSheet),
          matching: find.text('2118 Thornridge Cir.'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deliver to · Work'), findsOneWidget);
      expect(find.text('2118 Thornridge Cir.'), findsOneWidget);
      expect(find.text('6391 Elgin St.'), findsNothing);
    });

    testWidgets('an address deleted after it was chosen falls back',
        (tester) async {
      // The id is resolved against the book on every read, so a chosen
      // address that is gone cannot leave the screen pointed at nothing.
      final harness = CheckoutHarness(
        addresses: FakeAddressRepository(book: [home, work]),
      );
      await harness.pump(tester);

      harness.container
          .read(checkoutControllerProvider.notifier)
          .chooseAddress('addr-gone');
      await tester.pumpAndSettle();

      expect(find.text('Deliver to · Home'), findsOneWidget);
    });

    testWidgets('an empty book offers the address form', (tester) async {
      final harness = CheckoutHarness(
        addresses: FakeAddressRepository(),
      );
      await harness.pump(tester);

      expect(find.text('No address yet'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(harness.addressFormOpened, isTrue);
    });

    testWidgets('the sheet leads to the address form too', (tester) async {
      final harness = CheckoutHarness(
        addresses: FakeAddressRepository(book: [home]),
      );
      await harness.pump(tester);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a new address'));
      await tester.pumpAndSettle();

      expect(harness.addressFormOpened, isTrue);
    });

    testWidgets('a book that will not load says so and retries',
        (tester) async {
      final addresses = FakeAddressRepository(book: [home])
        ..loadError = const ApiException(
          failure: ApiFailure.network,
          message: 'No connection.',
        );
      await CheckoutHarness(addresses: addresses).pump(tester);

      expect(find.text('Could not load your addresses.'), findsOneWidget);
      expect(find.text('No connection.'), findsOneWidget);

      addresses.loadError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('6391 Elgin St.'), findsOneWidget);
    });
  });

  group('pickup', () {
    testWidgets('swaps the address for the branch it is collected from',
        (tester) async {
      await CheckoutHarness().pump(tester);

      await tester.tap(find.text('Pickup'));
      await tester.pumpAndSettle();

      expect(find.text('Pick up from'), findsOneWidget);
      expect(find.text('Probe North'), findsOneWidget);
      // The admin types the address with its own line breaks, which would
      // otherwise make this row three lines tall.
      expect(find.text('12 North Road, Dhaka 1207'), findsOneWidget);
      expect(find.text('Deliver to · Home'), findsNothing);
    });

    testWidgets('its Change opens the branch picker', (tester) async {
      await CheckoutHarness().pump(tester);

      await tester.tap(find.text('Pickup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a branch'), findsOneWidget);
    });

    testWidgets('a one-location store has nothing to change', (tester) async {
      await CheckoutHarness(
        branches: FakeBranchRepository(
          list: branchesFromFixture('branches_single'),
        ),
      ).pump(tester);

      await tester.tap(find.text('Pickup'));
      await tester.pumpAndSettle();

      expect(find.text('Food Menu Dev'), findsOneWidget);
      expect(find.text('Change'), findsNothing);
    });
  });

  group('placing the order', () {
    testWidgets('a missing phone is named next to the field', (tester) async {
      await CheckoutHarness().pump(tester);

      // Nothing is red before the first attempt.
      expect(find.text('Enter a phone number.'), findsNothing);

      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a phone number.'), findsOneWidget);
      expect(find.text('Enter the name for the order.'), findsNothing);
    });

    testWidgets('a complete form places it and confirms', (tester) async {
      final harness = CheckoutHarness();
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(harness.checkout.drafts, hasLength(1));

      // The order is read **back** by id rather than rendered from what the
      // checkout answered with.
      expect(harness.orders.requested, [1042]);
      expect(find.text('Order placed!'), findsOneWidget);

      // The cart is emptied server-side, so it has to be re-read: the mini
      // cart and the tab badge both watch it.
      expect(harness.cart.calls.where((c) => c == 'cart'), hasLength(2));

      await tester.tap(find.text('Back to home'));
      await tester.pumpAndSettle();

      expect(find.text('Menu'), findsOneWidget);
    });

    testWidgets('submits the server\'s own date and time, by type',
        (tester) async {
      final harness = CheckoutHarness();
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      // The slot row scrolls, so the fourth chip has to be brought in before
      // it can be tapped.
      final chip = find.text('11:30 pm – 11:45 pm');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      final extension = harness.checkout.lastExtension;
      expect(extension['fmp_order_time_type'], 'delivery');
      expect(extension['fmp_delivery_date'], 'November 10, 2026');
      expect(extension['fmp_delivery_time'], '11:30 pm');
      // The pickup and dine-in keys still go, empty: the schema types them
      // all as strings and an omitted one is rejected as null.
      expect(extension['fmp_pickup_date'], '');
      expect(extension['fmp_dinein_table'], '');
      expect(extension.keys, hasLength(9));
    });

    testWidgets('a pickup order carries the pickup fields', (tester) async {
      final harness = CheckoutHarness();
      await harness.pump(tester);

      await tester.tap(find.text('Pickup'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      final extension = harness.checkout.lastExtension;
      expect(extension['fmp_order_time_type'], 'pickup');
      expect(extension['fmp_pickup_date'], 'November 10, 2026');
      expect(extension['fmp_delivery_date'], '');
    });

    testWidgets('ASAP submits no time at all', (tester) async {
      // The server sends ASAP with an empty `value`, which is what the
      // plugin reads as "as soon as possible".
      final harness = CheckoutHarness();
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(harness.checkout.lastExtension['fmp_delivery_time'], '');
    });

    testWidgets('the address and the typed contact go on the order',
        (tester) async {
      final harness = CheckoutHarness(
        addresses: FakeAddressRepository(book: [home]),
      );
      await harness.pump(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Nurul Huda Chowdhury',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.enterText(find.byType(TextFormField).at(2), 'Gate code 4');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      final body = harness.checkout.lastBody;
      final billing = body['billing_address'] as Map<String, dynamic>;
      // Split on the **first** space, so the surname survives whole.
      expect(billing['first_name'], 'Nurul');
      expect(billing['last_name'], 'Huda Chowdhury');
      expect(billing['address_1'], '6391 Elgin St.');
      expect(billing['phone'], '01711 000111');
      expect(billing['email'], 'customer@foodmenu.test');
      expect(body['customer_note'], 'Gate code 4');
      // Sent for pickup too, and the address the driver is given.
      expect(body['shipping_address'], isA<Map<String, dynamic>>());
      expect(body['payment_method'], 'cod');
    });

    testWidgets('a refused order says why and keeps the cart', (tester) async {
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.http,
          statusCode: 400,
          code: 'woocommerce_rest_invalid_address',
          message: 'There was a problem with the provided billing address: '
              'Street address is required',
        );
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Street address is required'), findsOneWidget);
      expect(find.text('Order placed!'), findsNothing);
      expect(find.text('Place order'), findsOneWidget);
    });

    testWidgets('an order with no id is not confirmed', (tester) async {
      // A 200 with `order_id: 0` is a refusal dressed as a success.
      final harness = CheckoutHarness()..checkout.order = placedOrder(id: 0);
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(find.text('The order was not confirmed.'), findsOneWidget);
      expect(find.text('Order placed!'), findsNothing);
    });

    testWidgets('the button cannot be pressed twice', (tester) async {
      // A second press is a second order, so the guard has to be certain
      // rather than merely likely.
      final harness = CheckoutHarness(
        checkout: FakeCheckoutRepository(
          delay: const Duration(milliseconds: 200),
        ),
      );
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pump();

      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(harness.checkout.drafts, hasLength(1));
    });

    testWidgets('delivery with no address is refused before the form',
        (tester) async {
      await CheckoutHarness(addresses: FakeAddressRepository()).pump(tester);

      // The form is checked first, so it has to pass for the blocker to
      // be what the customer is told.
      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(find.text('Add a delivery address first.'), findsOneWidget);
      expect(find.text('Enter a phone number.'), findsNothing);
    });

    testWidgets('a store taking no orders cannot be ordered from',
        (tester) async {
      final fulfilment = FakeFulfilmentRepository()
        ..types = OrderTypes.fromJson({
          'types': [
            {'type': 'pickup', 'label': 'Pickup', 'enabled': false},
            {'type': 'delivery', 'label': 'Delivery', 'enabled': false},
          ],
        });
      await CheckoutHarness(fulfilment: fulfilment).pump(tester);

      // The form is checked first, so it has to pass for the blocker to
      // be what the customer is told.
      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(
        find.text('This store is not taking orders right now.'),
        findsOneWidget,
      );
    });

    testWidgets('a day with no open time has to be fixed first',
        (tester) async {
      final fulfilment = FakeFulfilmentRepository()
        ..slotsByType = {
          OrderTypeKind.delivery: slotsFromFixture('slots_closed'),
        };
      await CheckoutHarness(fulfilment: fulfilment).pump(tester);

      // The form is checked first, so it has to pass for the blocker to
      // be what the customer is told.
      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a time for your order.'), findsOneWidget);
    });
  });

  group('the payment method', () {
    testWidgets('is the store\'s own, not a label composed here',
        (tester) async {
      await CheckoutHarness().pump(tester);

      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Cash on delivery'), findsOneWidget);
      expect(find.text('Pay with cash upon delivery.'), findsOneWidget);
    });

    testWidgets('goes on the order by its gateway id', (tester) async {
      final harness = CheckoutHarness();
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(harness.checkout.lastBody['payment_method'], 'cod');
    });

    testWidgets('one the app cannot finish is shown but not choosable',
        (tester) async {
      // A store running only card would otherwise show an empty section and
      // no reason why.
      final harness = CheckoutHarness(
        // Both are available for this cart; only one is one the app can
        // finish.
        cart: FakeCartRepository(
          cart: cartFromFixture(
            'cart_with_item',
            paymentMethods: ['bacs', 'cod'],
          ),
        ),
        payment: FakePaymentRepository(
          methods: paymentMethodsFromFixture('payment_methods_mixed'),
        ),
      );
      await harness.pump(tester);

      expect(find.text('Direct bank transfer'), findsOneWidget);
      expect(find.textContaining('coming to the app soon'), findsOneWidget);

      await tester.tap(find.text('Direct bank transfer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      // The tap did nothing: cash on delivery is still what is submitted.
      expect(harness.checkout.lastBody['payment_method'], 'cod');
    });

    testWidgets('a store the app cannot pay at all refuses the order',
        (tester) async {
      final harness = CheckoutHarness(
        cart: FakeCartRepository(
          cart: cartFromFixture('cart_with_item', paymentMethods: ['stripe']),
        ),
        payment: FakePaymentRepository(
          methods: PaymentMethods.fromJson(const {
            'default': '',
            'methods': [
              {'id': 'stripe', 'title': 'Card', 'supported': false},
            ],
          }),
        ),
      );
      await harness.pump(tester);

      expect(find.textContaining('not in the app yet'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(
        find.text('This store has no payment method the app can use yet.'),
        findsOneWidget,
      );
      expect(harness.checkout.drafts, isEmpty);
    });

    testWidgets('a gateway the cart cannot use is left out', (tester) async {
      // Enabled store-wide is not the same as available for this order, and
      // the cart is WooCommerce's own answer for that.
      final harness = CheckoutHarness(
        payment: FakePaymentRepository(
          methods: paymentMethodsFromFixture('payment_methods_mixed'),
        ),
      );
      await harness.pump(tester);

      // The fixture cart offers `cod` only.
      expect(find.text('Cash on delivery'), findsOneWidget);
      expect(find.text('Direct bank transfer'), findsNothing);
    });

    testWidgets('a failed load offers a retry that asks again',
        (tester) async {
      final harness = CheckoutHarness()
        ..payment.failNext = const ApiException(
          failure: ApiFailure.network,
          message: 'No connection.',
        );
      await harness.pump(tester);

      expect(find.text('No connection.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Cash on delivery'), findsOneWidget);
    });
  });

  group('a refused order', () {
    /// Fills the form and taps, which is what every test below starts with.
    Future<void> attempt(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(1), '01711 000111');
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
    }

    testWidgets('keeps every field the customer filled in', (tester) async {
      // The whole point of task 6.5: trying again is one tap, not a second
      // checkout.
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server.',
        );
      await harness.pump(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Someone Else');
      await tester.enterText(find.byType(TextFormField).at(2), 'Gate code 4');
      await attempt(tester);

      expect(find.text('Someone Else'), findsOneWidget);
      expect(find.text('01711 000111'), findsOneWidget);
      expect(find.text('Gate code 4'), findsOneWidget);
      expect(find.text('Deliver to · Home'), findsOneWidget);
      expect(find.text('Cash on delivery'), findsOneWidget);
    });

    testWidgets('says so in a banner that stays', (tester) async {
      // Not a snackbar: a refusal has to still be there after the keyboard
      // has opened and a field three rows up has been fixed.
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server.',
        );
      await harness.pump(tester);
      await attempt(tester);

      expect(find.byType(CheckoutErrorBanner), findsOneWidget);
      expect(find.text('Could not reach the server.'), findsOneWidget);
      expect(
        find.textContaining('Nothing has been charged'),
        findsOneWidget,
      );
    });

    testWidgets('a dropped connection offers a retry that sends it again',
        (tester) async {
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server.',
        );
      await harness.pump(tester);
      await attempt(tester);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      // The identical order, and this time it lands.
      expect(harness.checkout.drafts, hasLength(2));
      expect(
        harness.checkout.drafts.first.toJson(),
        harness.checkout.drafts.last.toJson(),
      );
      expect(find.text('Order placed!'), findsOneWidget);
    });

    testWidgets('a rejected address is not offered one', (tester) async {
      // Sending the identical order again would be refused identically.
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.http,
          statusCode: 400,
          code: 'woocommerce_rest_invalid_address',
          message: 'There was a problem with the provided billing address.',
          data: {
            'errors': {
              'billing': ['Street address is required'],
            },
          },
        );
      await harness.pump(tester);
      await attempt(tester);

      expect(find.text('• Street address is required'), findsOneWidget);
      expect(find.textContaining('Check the details below'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a moved total takes the cart the refusal handed back',
        (tester) async {
      // The 409 carries the refreshed cart, so the summary and the bar catch
      // up without another request.
      final harness = CheckoutHarness()
        ..checkout.failNext = ApiException(
          failure: ApiFailure.http,
          statusCode: 409,
          code: 'woocommerce_rest_checkout_total_mismatch',
          message: 'The order total changed from &#036;7.90 to &#036;23.50.',
          data: {'cart': cartJsonFixture('cart_with_addons')},
        );
      await harness.pump(tester);
      await attempt(tester);

      // Decoded, not printed as `&#036;`.
      expect(
        find.text('The order total changed from \$7.90 to \$23.50.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CheckoutTotalBar),
          matching: find.text('\$23.50'),
        ),
        findsOneWidget,
      );
      // Taken from the error body rather than asked for again.
      expect(harness.cart.calls.where((c) => c == 'cart'), hasLength(1));
    });

    testWidgets('a cart refusal with no cart in it re-reads instead',
        (tester) async {
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.http,
          statusCode: 400,
          code: 'woocommerce_rest_cart_empty',
          message: 'Cannot place an order, your cart is empty.',
        );
      await harness.pump(tester);
      await attempt(tester);

      expect(harness.cart.calls.where((c) => c == 'cart'), hasLength(2));
    });

    testWidgets('can be dismissed', (tester) async {
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server.',
        );
      await harness.pump(tester);
      await attempt(tester);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckoutErrorBanner), findsNothing);
    });

    testWidgets('clears itself when the next attempt succeeds',
        (tester) async {
      final harness = CheckoutHarness()
        ..checkout.failNext = const ApiException(
          failure: ApiFailure.http,
          statusCode: 400,
          code: 'woocommerce_rest_invalid_address',
          message: 'There was a problem with the provided billing address.',
        );
      await harness.pump(tester);
      await attempt(tester);

      expect(find.byType(CheckoutErrorBanner), findsOneWidget);

      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(find.text('Order placed!'), findsOneWidget);
    });

    testWidgets('carries the total the customer agreed to', (tester) async {
      // WooCommerce refuses the order if the real total is higher than this,
      // so a price that moved cannot be charged unseen.
      final harness = CheckoutHarness();
      await harness.pump(tester);
      await attempt(tester);

      expect(harness.checkout.lastBody['expected_total'], '790');
    });
  });

  group('signed out', () {
    testWidgets('is asked for an account instead of an address',
        (tester) async {
      await CheckoutHarness().pump(tester, signedIn: false);

      expect(find.text('Sign in to order'), findsOneWidget);
      expect(find.text('Contact details'), findsNothing);
      expect(find.text('Deliver to · Home'), findsNothing);
      // The times are the same for everyone, so they still show.
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('cannot place the order', (tester) async {
      await CheckoutHarness().pump(tester, signedIn: false);

      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to place your order.'), findsOneWidget);
    });

    testWidgets('the prompt leads to sign-in', (tester) async {
      await CheckoutHarness().pump(tester, signedIn: false);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  testWidgets('renders in dark mode without error', (tester) async {
    final harness = CheckoutHarness();
    await harness.pump(tester, theme: AppTheme.dark());

    expect(tester.takeException(), isNull);
    expect(find.text('Order summary'), findsOneWidget);
  });
}

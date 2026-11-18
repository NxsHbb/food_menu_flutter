import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/checkout/domain/payment_return.dart';

void main() {
  const store = 'shop.test';

  PaymentNavigation classify(String url, {String? host = store}) =>
      classifyPaymentUrl(Uri.parse(url), storeHost: host);

  group('what a navigation inside the payment screen means (task 12.4)', () {
    test('the gateway and the store are both just pages', () {
      expect(
        classify('https://shop.test/checkout/order-pay/66/?key=wc_order_x'),
        PaymentNavigation.allow,
      );
      expect(
        classify('https://api.razorpay.com/v1/checkout/embedded'),
        PaymentNavigation.allow,
      );
      // A bank's 3-D Secure step is somebody else's host entirely.
      expect(classify('https://3dsecure.bank.test/auth'), PaymentNavigation.allow);
    });

    test('landing back on order-received is the end of it', () {
      expect(
        classify('https://shop.test/checkout/order-received/66/?key=wc_order_x'),
        PaymentNavigation.finished,
      );
    });

    test('so is WooCommerce cancelling the order', () {
      expect(
        classify('https://shop.test/checkout/?cancel_order=true&order=wc_x'),
        PaymentNavigation.finished,
      );
      // On a host the app does not know, `false` is the site's own way of
      // saying "not that" and the navigation is ordinary. On the shop's own
      // host it does not matter either way: being back there is the end of
      // the payment, whatever the query says.
      expect(
        classify('https://elsewhere.test/checkout/?cancel_order=false'),
        PaymentNavigation.allow,
      );
    });

    test('a UPI or banking app is handed to the system', () {
      // A webview cannot open these and fails silently on them, which looks
      // exactly like a dead button.
      expect(classify('upi://pay?pa=merchant@bank'), PaymentNavigation.delegate);
      expect(
        classify('intent://pay#Intent;scheme=upi;end'),
        PaymentNavigation.delegate,
      );
      expect(classify('tel:+8801712345678'), PaymentNavigation.delegate);
    });

    test('about:blank is the webview talking to itself', () {
      expect(classify('about:blank'), PaymentNavigation.allow);
    });

    test('the decision never depends on the host', () {
      // The store's domain differs per deployment, and a gateway can host
      // the return itself, so matching on a hostname would work in testing
      // and fail on somebody's production site.
      expect(
        classify('https://anything.example/x/order-received/9/'),
        PaymentNavigation.finished,
      );
    });
  });

  group('coming back to the shop is the end of it (fix)', () {
    test('PayPal cancels to the cart, and says nothing about it', () {
      // Found on a device: PayPal's "Cancel and return" landed here, the
      // webview rendered the shop's website inside the app, and the customer
      // was stranded on it.
      expect(
        classify('https://shop.test/cart/'),
        PaymentNavigation.finished,
      );
    });

    test('so does a bounce to the shop front or the checkout', () {
      expect(classify('https://shop.test/'), PaymentNavigation.finished);
      expect(
        classify('https://shop.test/checkout/'),
        PaymentNavigation.finished,
      );
    });

    test('but the page the payment started on is not a return', () {
      // The order-pay page is where the whole thing begins, and it is on the
      // shop's own host.
      expect(
        classify('https://shop.test/checkout/order-pay/66/?key=wc_order_x'),
        PaymentNavigation.allow,
      );
    });

    test('www is the same shop', () {
      expect(
        classify('https://www.shop.test/cart/'),
        PaymentNavigation.finished,
      );
    });

    test('the gateway is still somebody else', () {
      expect(
        classify('https://www.sandbox.paypal.com/checkoutnow?token=23C7'),
        PaymentNavigation.allow,
      );
      expect(
        classify('https://api.razorpay.com/v1/checkout/embedded'),
        PaymentNavigation.allow,
      );
    });

    test('with no host to compare, only the old rules apply', () {
      // A store whose host the app could not parse still gets the
      // order-received and cancel_order rules.
      expect(
        classify('https://shop.test/cart/', host: null),
        PaymentNavigation.allow,
      );
      expect(
        classify('https://shop.test/checkout/order-received/9/', host: null),
        PaymentNavigation.finished,
      );
    });
  });
}

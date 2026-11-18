import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/checkout/domain/payment_return.dart';

void main() {
  PaymentNavigation classify(String url) => classifyPaymentUrl(Uri.parse(url));

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
      // `false` is the live site's own way of saying "not that".
      expect(
        classify('https://shop.test/checkout/?cancel_order=false'),
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/checkout/domain/checkout_failure.dart';

import '../cart/fake_cart_repository.dart';

void main() {
  CheckoutFailure failureFor({
    ApiFailure failure = ApiFailure.http,
    int? status,
    String? code,
    String message = 'Refused.',
    Map<String, dynamic>? data,
  }) {
    return CheckoutFailure.from(
      ApiException(
        failure: failure,
        message: message,
        statusCode: status,
        code: code,
        data: data,
      ),
    );
  }

  group('what kind of refusal it is', () {
    test('a dropped connection is worth trying again', () {
      final failure = failureFor(failure: ApiFailure.network);

      expect(failure.kind, CheckoutFailureKind.connection);
      expect(failure.canRetry, isTrue);
    });

    test('so is a server that broke', () {
      final failure = failureFor(status: 503, code: 'internal_server_error');

      expect(failure.kind, CheckoutFailureKind.connection);
      expect(failure.canRetry, isTrue);
    });

    test('a rejected address is the customer\'s to fix', () {
      final failure = failureFor(
        status: 400,
        code: 'woocommerce_rest_invalid_address',
      );

      expect(failure.kind, CheckoutFailureKind.validation);
      // Sending the identical order again would be refused identically.
      expect(failure.canRetry, isFalse);
    });

    test('a moved total is about the cart', () {
      final failure = failureFor(
        status: 409,
        code: 'woocommerce_rest_checkout_total_mismatch',
      );

      expect(failure.kind, CheckoutFailureKind.cart);
      expect(failure.staleCart, isTrue);
    });

    test('an empty cart is too', () {
      expect(
        failureFor(status: 400, code: 'woocommerce_rest_cart_empty').kind,
        CheckoutFailureKind.cart,
      );
    });

    test('a refused gateway is about payment', () {
      expect(
        failureFor(
          status: 400,
          code: 'woocommerce_rest_checkout_payment_method_disabled',
        ).kind,
        CheckoutFailureKind.payment,
      );
    });

    test('a rejected token is about the session', () {
      expect(
        failureFor(status: 401, code: 'fmp_app_not_authenticated').kind,
        CheckoutFailureKind.auth,
      );
    });

    test('a rate limit is not offered an immediate retry', () {
      // It will work later, but not now, and a button spends another attempt.
      final failure = failureFor(status: 429, code: 'too_many_requests');

      expect(failure.canRetry, isFalse);
    });

    test('anything else is shown as the server put it', () {
      final failure = failureFor(code: 'something_new', message: 'Nope.');

      expect(failure.kind, CheckoutFailureKind.unknown);
      expect(failure.message, 'Nope.');
    });
  });

  group('what it says', () {
    test('decodes the entities WooCommerce escapes its messages with', () {
      // The real total-mismatch sentence arrives with `&#036;` where the
      // currency symbol should be.
      final failure = failureFor(
        status: 409,
        code: 'woocommerce_rest_checkout_total_mismatch',
        message: 'The order total changed from &#036;0.01 to &#036;3.95.',
      );

      expect(failure.message, 'The order total changed from \$0.01 to \$3.95.');
    });

    test('lists the per-field complaints the Store API attaches', () {
      final failure = failureFor(
        status: 400,
        code: 'woocommerce_rest_invalid_address',
        message: 'There was a problem with the provided billing address.',
        data: const {
          'errors': {
            'billing': ['Street address is required', 'Town / City is required'],
          },
        },
      );

      expect(failure.details, [
        'Street address is required',
        'Town / City is required',
      ]);
    });

    test('lists invalid parameters the same way', () {
      final failure = failureFor(
        status: 400,
        code: 'rest_invalid_param',
        message: 'Invalid parameter(s): extensions',
        data: const {
          'params': {'extensions': 'fmp_pickup_date is not of type string.'},
        },
      );

      expect(failure.details, ['fmp_pickup_date is not of type string.']);
    });

    test('does not repeat what the message already said', () {
      final failure = failureFor(
        message: 'Street address is required',
        code: 'woocommerce_rest_invalid_address',
        data: const {
          'errors': {
            'billing': ['Street address is required'],
          },
        },
      );

      expect(failure.details, isEmpty);
    });
  });

  group('the cart a refusal hands back', () {
    test('is taken from the error body', () {
      // A 409 answers with the refreshed cart, which saves asking for it.
      final failure = failureFor(
        status: 409,
        code: 'woocommerce_rest_checkout_total_mismatch',
        data: {'cart': cartJsonFixture('cart_with_addons')},
      );

      expect(failure.refreshedCart?.totals.totalPrice.format(), '\$23.50');
    });

    test('a cart that will not parse is simply absent', () {
      // Never let a refusal become a crash; the screen re-reads instead.
      final failure = failureFor(
        status: 409,
        code: 'woocommerce_rest_checkout_total_mismatch',
        data: const {'cart': 'not a cart'},
      );

      expect(failure.refreshedCart, isNull);
      expect(failure.staleCart, isTrue);
    });
  });
}

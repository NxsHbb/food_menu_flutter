import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/payment_method.dart';

/// What the store accepts — `GET fmp/v1/app/payment-methods`.
///
/// A plugin route rather than a Store API one: the cart reports gateway
/// **ids** and nothing else, and the words beside the radio button belong to
/// the merchant.
class PaymentRepository {
  const PaymentRepository(this._client);

  final ApiClient _client;

  Future<PaymentMethods> methods() async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/payment-methods'),
    );
    return PaymentMethods.fromJson(raw);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});

/// The store's gateways. Stable for the session — the list does not depend on
/// the cart, which is the whole reason it is not on the cart.
final paymentMethodsProvider = FutureProvider<PaymentMethods>(
  (ref) => ref.watch(paymentRepositoryProvider).methods(),
  // The section offers "Try again"; a background retry would keep firing
  // while the customer reads the error, as with the order types.
  retry: (retryCount, error) => null,
);

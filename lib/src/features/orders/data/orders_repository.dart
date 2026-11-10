import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/customer_order.dart';

/// The customer's own orders — `GET fmp/v1/app/orders/{id}`.
///
/// A plugin route rather than `wc/store/v1/order/{id}`, which carries no
/// order number, no date, no payment title and none of the plugin's own
/// fields — including the tracking token. See `CONTEXT.md`.
class OrdersRepository {
  const OrdersRepository(this._client);

  final ApiClient _client;

  Future<CustomerOrder> order(int id) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/orders/$id'),
    );
    return CustomerOrder.fromJson(raw);
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});

/// One order, by id.
///
/// Keyed by id so returning to an order already read does not refetch, and
/// invalidated rather than refetched by hand when a screen wants it fresh.
final orderProvider = FutureProvider.family<CustomerOrder, int>(
  (ref, id) => ref.watch(ordersRepositoryProvider).order(id),
  // The screen offers "Try again"; a background retry would keep firing while
  // the customer reads the error, as everywhere else in the app.
  retry: (retryCount, error) => null,
);

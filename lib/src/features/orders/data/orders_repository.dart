import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import '../domain/customer_order.dart';
import '../domain/order_summary.dart';
import '../domain/order_tracking.dart';

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

  /// Where one order has got to.
  ///
  /// A plugin route and **not** the public `fmp/v1/track/{token}`, even though
  /// the order payload carries the token: that one answers only what already
  /// happened, and it expires. See [OrderTracking].
  Future<OrderTracking> tracking(int id) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/orders/$id/tracking'),
    );
    return OrderTracking.fromJson(raw);
  }

  /// One page of the history, newest first.
  ///
  /// Paged through [ApiClient.getPaged] rather than an envelope, because the
  /// route answers a bare array with `X-WP-Total` — the same contract the
  /// menu list speaks.
  Future<Paged<OrderSummary>> orders({
    required OrderGroup group,
    int page = 1,
  }) async {
    final raw = await _client.getPaged(
      _client.foodMenuApi('app/orders'),
      query: {'group': group.value, 'per_page': _perPage},
      page: page,
    );

    return Paged(
      items: raw.items.map(OrderSummary.fromJson).toList(growable: false),
      total: raw.total,
      totalPages: raw.totalPages,
      page: raw.page,
    );
  }

  /// Enough to fill a phone twice over, so the first scroll rarely stalls.
  static const _perPage = 10;
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

/// Where one order has got to, by id.
///
/// **Separate from [orderProvider] on purpose.** The order itself is settled
/// — its items, totals and address do not change — while its progress is the
/// one part that does, so a refresh re-reads this and leaves the rest alone.
/// It also means a tracking failure costs the timeline and not the whole
/// screen: the design's order detail is worth drawing without it.
final orderTrackingProvider = FutureProvider.family<OrderTracking, int>(
  (ref, id) => ref.watch(ordersRepositoryProvider).tracking(id),
  retry: (retryCount, error) => null,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/order_draft.dart';
import '../domain/placed_order.dart';

/// Placing the order — `POST wc/store/v1/checkout`.
///
/// The Store API's own route, not a plugin one: the order, its totals, stock
/// and the gateway are WooCommerce's business, and the plugin only adds the
/// pickup/delivery fields the draft carries in `extensions`.
///
/// Like every Store API write it needs the `Nonce` and `Cart-Token` headers,
/// which `StoreSessionInterceptor` carries, and the branch header, which
/// `BranchInterceptor` carries — the plugin reads that one to file the order
/// under the branch the customer is ordering from.
class CheckoutRepository {
  const CheckoutRepository(this._client);

  final ApiClient _client;

  /// Places the order and returns what the server made of it.
  ///
  /// **The cart is emptied server-side** by a successful checkout, so a caller
  /// has to re-read it rather than assume the lines are still there.
  Future<PlacedOrder> placeOrder(OrderDraft draft) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _client.storeApi('checkout'),
      body: draft.toJson(),
    );
    return PlacedOrder.fromJson(raw);
  }
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/store_api/models/cart.dart';

/// The WooCommerce Store API cart.
///
/// Every route here writes, and every write needs the `Nonce` and
/// `Cart-Token` headers the API hands back — carried automatically by
/// `StoreSessionInterceptor`, so nothing in this class touches them.
///
/// All four routes return **the whole cart**, so a mutation never needs a
/// follow-up read: the response is the new state.
class CartRepository {
  const CartRepository(this._client);

  final ApiClient _client;

  Future<Cart> cart() async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.storeApi('cart'),
    );
    return Cart.fromJson(raw);
  }

  /// Adds a dish, with any add-on selections.
  ///
  /// [addons] is the payload `AddonSelection.toPayload()` builds, sent under
  /// the plugin's own extension key — the Store API's own body takes only
  /// `id`, `quantity` and `variation`, which is the gap task 4.2 closed.
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<Map<String, Object>> addons = const [],
    List<Map<String, Object>> variation = const [],
  }) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _client.storeApi('cart/add-item'),
      body: {
        // **The parent's id, even for a variable dish.** The server resolves
        // the variation from the attributes below and the cart line comes
        // back under the variation's own id.
        'id': productId,
        'quantity': quantity,
        if (variation.isNotEmpty) 'variation': variation,
        if (addons.isNotEmpty)
          'extensions': {
            'food-menu-pro': {'addons': addons},
          },
      },
    );
    return Cart.fromJson(raw);
  }

  /// Sets a line's quantity. Addressed by [key], never by product id: the
  /// same dish ordered two ways is two lines sharing one id.
  Future<Cart> updateItem({
    required String key,
    required int quantity,
  }) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _client.storeApi('cart/update-item'),
      body: {'key': key, 'quantity': quantity},
    );
    return Cart.fromJson(raw);
  }

  Future<Cart> removeItem({required String key}) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _client.storeApi('cart/remove-item'),
      body: {'key': key},
    );
    return Cart.fromJson(raw);
  }

  /// Empties the cart, for the design's "Clear all".
  ///
  /// The odd one out: `DELETE cart/items` answers with the **items list**,
  /// which is `[]`, not with the cart — so the totals have to be read back
  /// rather than taken from the response.
  Future<Cart> clear() async {
    await _client.delete<List<dynamic>>(_client.storeApi('cart/items'));
    return cart();
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

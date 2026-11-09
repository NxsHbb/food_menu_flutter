import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/store_api/models/product.dart';

/// Talks to `fmp/v1/app/wishlist`.
///
/// Every route here needs the bearer token, so nothing in this class works
/// for a signed-out customer — [WishlistController] is what knows that.
class WishlistRepository {
  const WishlistRepository(this._client);

  final ApiClient _client;

  String get _url => _client.foodMenuApi('app/wishlist');

  /// The customer's favourites, newest first.
  ///
  /// The server returns whole Store API product payloads, so these are the
  /// same [Product] objects the menu renders and no second fetch is needed.
  ///
  /// `items` is the list the server could render; a favourite whose dish is
  /// currently off the menu is absent from it while remaining saved. That is
  /// why the id set for the hearts is derived from this list rather than read
  /// from a separate field — a heart the app cannot show must not be filled.
  Future<List<Product>> all() async {
    final raw = await _client.get<Map<String, dynamic>>(_url);
    final items = raw['items'];

    if (items is! List) return const [];

    return items
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Adds a dish. Succeeds whether or not it was already saved.
  Future<void> add(int productId) async {
    await _client.post<Map<String, dynamic>>(
      _url,
      body: {'product_id': productId},
    );
  }

  /// Removes a dish. Succeeds whether or not it was saved.
  ///
  /// The id goes in the path, not a body: a DELETE body is legal but widely
  /// dropped in transit.
  Future<void> remove(int productId) async {
    await _client.delete<Map<String, dynamic>>('$_url/$productId');
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.watch(apiClientProvider));
});

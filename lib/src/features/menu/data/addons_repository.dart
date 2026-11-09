import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/product_addons.dart';

/// Reads a dish's add-on groups from the plugin's own namespace.
///
/// `GET fmp/v1/app/products/{id}/addons` is the one route in `fmp/v1/app/*`
/// that needs no token: the dish screen is reachable before sign-in, and
/// nothing in the answer is customer data.
class AddonsRepository {
  const AddonsRepository(this._client);

  final ApiClient _client;

  Future<ProductAddons> forProduct(int productId) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/products/$productId/addons'),
    );
    return ProductAddons.fromJson(raw);
  }
}

final addonsRepositoryProvider = Provider<AddonsRepository>((ref) {
  return AddonsRepository(ref.watch(apiClientProvider));
});

/// A dish's add-on groups, or none at all.
///
/// **Never an error state.** This route only exists on a store running a Pro
/// build new enough to have it, so an older store answers 404 — and a dish
/// that cannot be customised is a perfectly good dish. Failing here would
/// take the whole detail screen down over an optional section, so anything
/// that goes wrong resolves to no groups and the screen simply does not draw
/// them.
final productAddonsProvider =
    FutureProvider.family<ProductAddons, int>((ref, productId) async {
  try {
    return await ref.watch(addonsRepositoryProvider).forProduct(productId);
  } on Object {
    return ProductAddons.none(productId);
  }
});

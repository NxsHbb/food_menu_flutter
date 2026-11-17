import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/store_config.dart';

/// Reads `GET fmp/v1/app/config` (task 14.3).
class StoreConfigRepository {
  const StoreConfigRepository(this._client);

  final ApiClient _client;

  /// The store, or [StoreConfig.unknown] when this Pro is too old to say.
  ///
  /// **A 404 is not a failure here.** The route is the newest thing the app
  /// asks for, so an older Pro answers 404 to it while everything else still
  /// works — which is exactly the behaviour task 14.7 will generalise. Any
  /// other failure is a real one and is thrown, so a caller can retry rather
  /// than quietly pretend it knows the store.
  Future<StoreConfig> config() async {
    try {
      final raw = await _client.get<Map<String, dynamic>>(
        _client.foodMenuApi('app/config'),
      );
      return StoreConfig.fromJson(raw);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return StoreConfig.unknown;
      rethrow;
    }
  }
}

final storeConfigRepositoryProvider = Provider<StoreConfigRepository>((ref) {
  return StoreConfigRepository(ref.watch(apiClientProvider));
});

/// The store, read once at launch.
///
/// Watched by the app root for the theme, so it is one of the first requests
/// made. Never re-read on its own: see [StoreConfig] for why nothing that has
/// to be fresh belongs in it.
final storeConfigProvider = FutureProvider<StoreConfig>((ref) {
  return ref.watch(storeConfigRepositoryProvider).config();
});

/// The store's colour, or null while loading, on failure, or when it has none.
///
/// Null rather than the app's red on purpose: the root applies the app's own
/// palette for null, so "not yet known" and "no colour set" take the same
/// path and the theme never flickers through a wrong brand.
final storeBrandProvider = Provider<Color?>((ref) {
  return ref.watch(storeConfigProvider).value?.primaryColor;
});

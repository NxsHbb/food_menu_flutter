import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/product.dart';
import '../../auth/data/auth_controller.dart';
import 'wishlist_repository.dart';

/// The customer's saved dishes.
///
/// One load per sign-in, held here for the whole session. The hearts scattered
/// across the menu read [wishlistIdsProvider] off this list rather than asking
/// the server per card — with a grid of dishes on screen that would be a
/// request per card for information one request already carries.
///
/// Signed out is an empty list, not an error: the menu still renders, and the
/// hearts simply have nothing to fill. Watching [authControllerProvider] means
/// signing in loads the wishlist and signing out drops it, with no explicit
/// invalidation anywhere.
class WishlistController extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    if (!ref.watch(isSignedInProvider)) return const [];

    return ref.read(wishlistRepositoryProvider).all();
  }

  /// Saves or unsaves a dish, updating the list before the server replies.
  ///
  /// Optimistic because a heart that waits for a round trip feels broken, and
  /// the write it is reflecting is idempotent either way. On failure the whole
  /// previous list is put back and the error rethrown for the caller to show.
  ///
  /// Favouriting can prepend the product immediately because the heart is
  /// always rendered next to a dish the app has already loaded — so the
  /// wishlist screen is correct the moment the heart fills, without a refetch.
  Future<void> toggle(Product product) async {
    // Awaits the first load rather than ignoring the tap: a heart tapped
    // during the opening request would otherwise do nothing, and the window
    // is exactly when a customer is first looking at the menu.
    final current = await future;

    final wasSaved = current.any((p) => p.id == product.id);
    final next = wasSaved
        ? current.where((p) => p.id != product.id).toList(growable: false)
        : [product, ...current];

    state = AsyncData(next);

    try {
      if (wasSaved) {
        await ref.read(wishlistRepositoryProvider).remove(product.id);
      } else {
        await ref.read(wishlistRepositoryProvider).add(product.id);
      }
    } on ApiException catch (error) {
      state = AsyncData(current);

      // The dish has left the menu, so the list the app is holding is stale
      // in more ways than this one heart. Reload rather than only reverting.
      if (error.statusCode == 404) {
        ref.invalidateSelf();
      }

      rethrow;
    }
  }

  /// Re-reads the wishlist, for pull-to-refresh on the wishlist screen.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(wishlistRepositoryProvider).all(),
    );
  }
}

final wishlistControllerProvider =
    AsyncNotifierProvider<WishlistController, List<Product>>(
  WishlistController.new,
  // Riverpod retries a failed build on its own, with backoff. Switched off
  // here: the wishlist screen already offers "Try again", so a background
  // retry only adds a timer that keeps firing while the customer looks at the
  // error — and it stops `.future` ever completing with the error, which hides
  // a failed load from anything that awaits it.
  retry: (retryCount, error) => null,
);

/// Which dishes are saved, for the hearts.
///
/// A set, because every dish card on screen asks this question on every build.
/// Falls back to empty while the first load is in flight, so a heart is never
/// drawn filled on a guess.
final wishlistIdsProvider = Provider<Set<int>>((ref) {
  final wishlist = ref.watch(wishlistControllerProvider).value;

  return wishlist == null
      ? const {}
      : {for (final product in wishlist) product.id};
});

/// How many dishes are saved, for the Account screen's row.
final wishlistCountProvider = Provider<int>((ref) {
  return ref.watch(wishlistIdsProvider).length;
});

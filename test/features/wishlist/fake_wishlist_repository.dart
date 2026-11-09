import 'package:food_menu/src/core/store_api/models/product.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_repository.dart';

/// A [WishlistRepository] that answers from memory.
///
/// Adds and removes are applied to [saved] so a test can assert the list the
/// screen ends up with, not only the calls it made.
class FakeWishlistRepository implements WishlistRepository {
  FakeWishlistRepository({
    List<Product> saved = const [],
    this.delay = Duration.zero,
  }) : saved = List.of(saved);

  /// The wishlist as the server holds it, newest first.
  final List<Product> saved;

  final Duration delay;

  /// Thrown by [all] when set.
  Object? loadError;

  /// Thrown by [add] and [remove] when set.
  Object? writeError;

  /// Every call made, as `('all'|'add'|'remove', productId)`.
  final List<({String call, int? productId})> calls = [];

  /// Products the fake should return from [add], keyed by id, so a test can
  /// reload and see what the server would have had.
  final Map<int, Product> catalogue = {};

  @override
  Future<List<Product>> all() async {
    calls.add((call: 'all', productId: null));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (loadError != null) throw loadError!;
    return List.of(saved);
  }

  @override
  Future<void> add(int productId) async {
    calls.add((call: 'add', productId: productId));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (writeError != null) throw writeError!;

    if (saved.every((p) => p.id != productId)) {
      final product = catalogue[productId];
      if (product != null) saved.insert(0, product);
    }
  }

  @override
  Future<void> remove(int productId) async {
    calls.add((call: 'remove', productId: productId));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (writeError != null) throw writeError!;

    saved.removeWhere((p) => p.id == productId);
  }
}

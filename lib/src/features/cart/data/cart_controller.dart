import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/store_api/models/cart.dart';
import 'cart_repository.dart';

/// The customer's cart, held for the session.
///
/// Every Store API cart route answers with the **whole cart**, so a mutation
/// is a single round trip and its response is the new state — there is no
/// read-after-write anywhere here.
///
/// Mutations are **not** optimistic, unlike the wishlist's hearts. A cart line
/// carries money, and the server is the only thing that knows what a quantity
/// change costs once the plugin's discounts and the add-on pricing have had
/// their say. Showing a total the server has not agreed to, even for a few
/// hundred milliseconds, is the one thing a cart must not do. Instead the line
/// being changed is marked [pending] so the row can show it is working.
class CartController extends AsyncNotifier<Cart> {
  @override
  Future<Cart> build() {
    // **Watched, not read.** The repository is rebuilt when the order type
    // changes, and re-reading the cart is the whole point: switching to
    // pickup takes the delivery fee off the totals, and a customer who was
    // shown $22.95 has to see it become $13.00 on the same tap rather than
    // at the next thing that happens to touch the cart.
    return ref.watch(cartRepositoryProvider).cart();
  }

  /// Takes a cart the server handed back somewhere other than a cart route.
  ///
  /// The checkout's total-mismatch refusal carries the **refreshed cart** in
  /// its error body, so adopting it is both faster and more accurate than
  /// asking again — anything that changed in between would be missed by a
  /// second request anyway.
  void adopt(Cart cart) => state = AsyncData(cart);

  /// Line keys with a request in flight.
  final _pending = <String>{};

  bool isPending(String key) => _pending.contains(key);

  /// Adds a dish with its chosen add-ons.
  ///
  /// Returns the line the server created, which is **not** necessarily a new
  /// one: adding the same dish with the same choices again raises the
  /// quantity of the line already there, as the website does.
  Future<CartItem?> add({
    required int productId,
    int quantity = 1,
    List<Map<String, Object>> addons = const [],
    List<Map<String, Object>> variation = const [],
    int? variationId,
  }) async {
    final before = state.value;

    final cart = await ref.read(cartRepositoryProvider).addItem(
          productId: productId,
          quantity: quantity,
          addons: addons,
          variation: variation,
        );

    state = AsyncData(cart);

    // **The line comes back under the variation's id, never the parent's**,
    // so a variable dish is looked up by the variation the selection
    // resolved to. See `FINDINGS.md`.
    return _addedLine(before, cart, variationId ?? productId);
  }

  /// Sets a line's quantity, within the limits the server published for it.
  ///
  /// A quantity of zero removes the line, which is what the stepper's minus
  /// does on its last step.
  Future<void> setQuantity(CartItem item, int quantity) async {
    if (quantity <= 0) return remove(item);

    final wanted = item.quantityLimits.clamp(quantity);
    if (wanted == item.quantity) return;

    await _mutate(
      item.key,
      () => ref.read(cartRepositoryProvider).updateItem(
            key: item.key,
            quantity: wanted,
          ),
    );
  }

  Future<void> remove(CartItem item) {
    return _mutate(
      item.key,
      () => ref.read(cartRepositoryProvider).removeItem(key: item.key),
    );
  }

  /// Removes every line for any of [productIds].
  ///
  /// A product can own more than one line — the same dish added twice with
  /// different add-ons — so this works off the product id and removes all of
  /// them, where [remove] takes one line.
  ///
  /// Sequential rather than concurrent: each cart route answers with the whole
  /// cart, so two removals in flight together would each describe a cart
  /// without the other's line and whichever landed last would win.
  Future<void> removeProducts(Set<int> productIds) async {
    if (productIds.isEmpty) return;

    // Collected up front, because `state` is replaced by every removal and
    // iterating it while it changes would skip lines.
    final doomed = [
      for (final item in state.value?.items ?? const <CartItem>[])
        if (productIds.contains(item.id)) item,
    ];

    for (final item in doomed) {
      await remove(item);
    }
  }

  /// Chooses how the order is delivered (task 8.5).
  ///
  /// Keyed on the rate so the row being chosen can show itself as busy, and
  /// run through [_mutate] like any other change: picking a rate moves the
  /// total, and a failure must leave the cart the customer is reading intact.
  Future<void> selectShippingRate({
    required int packageId,
    required String rateId,
  }) {
    return _mutate(
      'shipping:$rateId',
      () => ref.read(cartRepositoryProvider).selectShippingRate(
            packageId: packageId,
            rateId: rateId,
          ),
    );
  }

  /// Empties the cart.
  Future<void> clear() async {
    final cart = await ref.read(cartRepositoryProvider).clear();
    state = AsyncData(cart);
  }

  /// Sets or clears the tip (task 9.4). Zero removes it.
  ///
  /// Not optimistic, like every other cart mutation here: a percentage tip is
  /// the server's arithmetic over the server's subtotal, and showing a figure
  /// it has not agreed to is the one thing a cart must not do.
  Future<void> setTip({required String type, required int amount}) async {
    final cart = await ref
        .read(cartRepositoryProvider)
        .setTip(type: type, amount: amount);
    state = AsyncData(cart);
  }

  /// Re-reads the cart, for pull-to-refresh and for recovering from an error.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cartRepositoryProvider).cart(),
    );
  }

  /// Runs a mutation with [key] marked as busy.
  ///
  /// The error is rethrown for the screen to show, but the cart is left as the
  /// server last described it rather than being dropped into an error state:
  /// a failed quantity change should not blank a cart the customer is reading.
  Future<void> _mutate(String key, Future<Cart> Function() request) async {
    _pending.add(key);
    // Re-emitting the current value is what makes the busy flag visible, since
    // `_pending` is not itself part of the state.
    _touch();

    try {
      state = AsyncData(await request());
    } finally {
      _pending.remove(key);
      _touch();
    }
  }

  void _touch() {
    final current = state.value;
    if (current != null) state = AsyncData(current);
  }

  /// The line this add landed on, found by comparing before and after.
  ///
  /// A key that was not there before is the new line. Failing that — the add
  /// raised an existing line's quantity — it is the line for this product
  /// whose quantity grew, and if even that is ambiguous, the last line for
  /// the product. Used only to say "added" with the right line, so a wrong
  /// guess costs nothing.
  ///
  /// [productId] is **the id the line will carry**, which for a variable dish
  /// is the variation's rather than the parent's.
  CartItem? _addedLine(Cart? before, Cart after, int productId) {
    final known = {for (final item in before?.items ?? const []) item.key};

    for (final item in after.items) {
      if (!known.contains(item.key)) return item;
    }

    CartItem? fallback;
    for (final item in after.items.where((i) => i.id == productId)) {
      fallback = item;
      final previous = before?.itemByKey(item.key);
      if (previous != null && item.quantity > previous.quantity) return item;
    }

    return fallback;
  }
}

final cartControllerProvider = AsyncNotifierProvider<CartController, Cart>(
  CartController.new,
  // The cart screen offers "Try again", and a background retry would keep
  // firing while the customer reads the error — and would stop `.future`
  // completing, hiding a failed load from anything that awaits it.
  retry: (retryCount, error) => null,
);

/// How many units are in the cart, for the tab badge and the mini cart.
///
/// Zero while the first read is in flight, so a badge is never drawn on a
/// guess.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartControllerProvider).value?.itemsCount ?? 0;
});

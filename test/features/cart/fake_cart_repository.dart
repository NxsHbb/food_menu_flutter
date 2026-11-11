export 'package:food_menu/src/core/store_api/models/cart.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/core/store_api/models/cart.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';

/// A [CartRepository] that answers from memory, so cart tests never touch the
/// network.
///
/// It keeps a cart rather than returning a canned answer, because the real
/// routes all answer with the whole cart and the screen depends on that: a
/// quantity change has to come back as a changed cart or nothing moves.
class FakeCartRepository implements CartRepository {
  FakeCartRepository({Cart? cart, this.delay = Duration.zero})
      : _cart = cart ?? Cart.empty();

  Cart _cart;
  final Duration delay;

  /// Thrown by the next call of any kind, then cleared. Use this for a
  /// failed first read.
  Object? failNext;

  /// Thrown by the next **write**, then cleared.
  ///
  /// Separate from [failNext] because a controller reads the cart when it is
  /// first touched, and a plain `failNext` would be spent on that read rather
  /// than on the mutation the test meant to fail.
  Object? failNextWrite;

  /// Every call made, in order, as `'add 25 x2'`, `'update <key> 3'`,
  /// `'remove <key>'`, `'clear'` or `'cart'`.
  final List<String> calls = [];

  /// The add-on payloads passed to [addItem].
  final List<List<Map<String, Object>>> addonPayloads = [];

  /// Replaces what the next read or mutation will answer with.
  void seed(Cart cart) => _cart = cart;

  Future<Cart> _answer({bool write = false}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNext ?? (write ? failNextWrite : null);
    if (failure != null) {
      if (failNext != null) {
        failNext = null;
      } else {
        failNextWrite = null;
      }
      throw failure;
    }
    return _cart;
  }

  @override
  Future<Cart> cart() {
    calls.add('cart');
    return _answer();
  }

  /// The variation payloads passed to [addItem].
  final List<List<Map<String, Object>>> variationPayloads = [];

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<Map<String, Object>> addons = const [],
    List<Map<String, Object>> variation = const [],
  }) {
    calls.add('add $productId x$quantity');
    addonPayloads.add(addons);
    variationPayloads.add(variation);
    return _answer(write: true);
  }

  @override
  Future<Cart> updateItem({required String key, required int quantity}) {
    calls.add('update $key $quantity');
    _cart = _withItems([
      for (final item in _cart.items)
        if (item.key == key) _requantified(item, quantity) else item,
    ]);
    return _answer(write: true);
  }

  @override
  Future<Cart> removeItem({required String key}) {
    calls.add('remove $key');
    _cart = _withItems(
      _cart.items.where((item) => item.key != key).toList(growable: false),
    );
    return _answer(write: true);
  }

  @override
  Future<Cart> clear() {
    calls.add('clear');
    _cart = _withItems(const []);
    return _answer(write: true);
  }

  /// The same line at a new quantity, with its line total recomputed — which
  /// is what the server does, and what the row shows.
  CartItem _requantified(CartItem item, int quantity) {
    final lineTotal = item.prices.price * quantity;

    return CartItem(
      key: item.key,
      id: item.id,
      quantity: quantity,
      name: item.name,
      prices: item.prices,
      totals: CartItemTotals(
        lineSubtotal: lineTotal,
        lineTotal: lineTotal,
        currency: item.totals.currency,
      ),
      images: item.images,
      itemData: item.itemData,
      quantityLimits: item.quantityLimits,
      shortDescription: item.shortDescription,
      addons: item.addons,
    );
  }

  Cart _withItems(List<CartItem> items) {
    return Cart(
      items: items,
      itemsCount: items.fold(0, (sum, item) => sum + item.quantity),
      totals: _cart.totals,
      needsPayment: _cart.needsPayment,
      needsShipping: _cart.needsShipping,
      paymentMethods: _cart.paymentMethods,
      errors: _cart.errors,
    );
  }
}

/// The raw cart payload, for the tests that need to put one somewhere other
/// than a cart route — the checkout's total-mismatch refusal carries one in
/// its error body.
Map<String, dynamic> cartJsonFixture(String name) {
  return jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
      as Map<String, dynamic>;
}

/// Reads a cart payload from `test/fixtures`.
///
/// [paymentMethods] patches the captured payload rather than the model, for
/// the cases where which gateways a cart can use is the thing under test —
/// the fixtures were captured from a store with one.
Cart cartFromFixture(String name, {List<String>? paymentMethods}) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
      as Map<String, dynamic>;

  if (paymentMethods != null) json['payment_methods'] = paymentMethods;

  return Cart.fromJson(json);
}

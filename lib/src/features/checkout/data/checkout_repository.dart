import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../fulfilment/domain/order_types.dart';
import '../domain/checkout_config.dart';
import '../domain/checkout_field.dart';
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
/// under the branch the customer is ordering from. The order **type** header
/// is set here instead, from the draft: see [placeOrder].
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
      // **From the draft, not from a provider.** The order is created from
      // the cart during this request, so this is the last chance to say that
      // a pickup order ships nothing — and the draft is the thing the
      // customer actually agreed to, which no amount of state settling in
      // the background can contradict.
      headers: {OrderTypeKind.header: draft.type.name},
    );
    return PlacedOrder.fromJson(raw);
  }

  /// The store's own checkout questions.
  ///
  /// A plugin route, since the Store API knows nothing about them. Public, so
  /// the checkout can be drawn before the customer signs in.
  Future<CheckoutConfig> config() async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.foodMenuApi('app/checkout-fields'),
    );

    final sections = raw['sections'];
    final texts = raw['texts'];

    return CheckoutConfig(
      fields: _fields(raw),
      // Absent on an older plugin, which is a store that has asked for
      // nothing — so everything is drawn and the app keeps its own wording.
      sections: sections is Map
          ? CheckoutSections.fromJson(sections.cast<String, dynamic>())
          : CheckoutSections.all,
      texts: texts is Map
          ? CheckoutTexts.fromJson(texts.cast<String, dynamic>())
          : CheckoutTexts.none,
    );
  }

  List<CheckoutField> _fields(Map<String, dynamic> raw) {
    // The store's master switch for the whole section. Off means the website
    // draws none of them, so neither does the app.
    if (raw['enabled'] != true) return const [];

    final fields = raw['fields'];
    if (fields is! List) return const [];

    return fields
        .whereType<Map>()
        .map((e) => CheckoutField.fromJson(e.cast<String, dynamic>()))
        .where((field) => field.isUsable)
        .toList(growable: false);
  }
}

/// The store's checkout questions, or none.
///
/// **Never an error state.** A store on an older plugin has no route, and a
/// checkout that refuses to draw because an optional section could not load
/// would be worse than one without it. A failure resolves to no fields, as
/// the add-ons provider does.
final checkoutConfigProvider = FutureProvider<CheckoutConfig>((ref) async {
  try {
    return await ref.watch(checkoutRepositoryProvider).config();
  } on Object {
    return CheckoutConfig.empty;
  }
});

/// The store's checkout questions, or none.
final checkoutFieldsProvider = Provider<List<CheckoutField>>((ref) {
  return ref.watch(checkoutConfigProvider).value?.fields ?? const [];
});

/// Which parts of the checkout to draw. Everything, until a store says less.
final checkoutSectionsProvider = Provider<CheckoutSections>((ref) {
  return ref.watch(checkoutConfigProvider).value?.sections ??
      CheckoutSections.all;
});

/// The store's own words, where it has any.
final checkoutTextsProvider = Provider<CheckoutTexts>((ref) {
  return ref.watch(checkoutConfigProvider).value?.texts ?? CheckoutTexts.none;
});

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});

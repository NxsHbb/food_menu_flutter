/// How a store can be paid — `GET fmp/v1/app/payment-methods`.
///
/// **The words are the merchant's.** WooCommerce's gateway titles are
/// translated and routinely renamed — a store that calls cash on delivery
/// "Pay the rider" means it — so nothing here is composed in Dart.
class PaymentMethods {
  const PaymentMethods({required this.defaultId, required this.methods});

  factory PaymentMethods.fromJson(Map<String, dynamic> json) {
    final raw = json['methods'];

    return PaymentMethods(
      defaultId: json['default'] as String? ?? '',
      methods: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => PaymentMethod.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  static const empty = PaymentMethods(defaultId: '', methods: []);

  /// What to preselect: the store's first gateway the app can finish, or
  /// empty when it has none.
  final String defaultId;

  /// Every **enabled** gateway, in the store's own order — including the ones
  /// the app cannot complete, so a store running only Stripe gets an
  /// explanation rather than an empty section.
  final List<PaymentMethod> methods;

  PaymentMethod? byId(String? id) {
    if (id == null) return null;
    for (final method in methods) {
      if (method.id == id) return method;
    }
    return null;
  }

  /// The methods on offer for one cart.
  ///
  /// **Availability is the cart's business, not this route's**: a gateway can
  /// be enabled store-wide and still be unavailable for a particular order,
  /// over a country or a total. `Cart.paymentMethods` is WooCommerce's own
  /// answer for that cart, so the two are intersected rather than either
  /// being trusted alone.
  ///
  /// **Null is not the same as empty.** Null is a cart that has not been read
  /// yet, and the whole list stands until it has; an empty list is a cart
  /// nothing can pay for, which is a real answer and leaves nothing to show.
  List<PaymentMethod> offered(List<String>? available) {
    if (available == null) return methods;

    return methods
        .where((method) => available.contains(method.id))
        .toList(growable: false);
  }

  /// What a screen should treat as chosen.
  ///
  /// Resolved on every read, like the order type and the slot: a store can
  /// switch a gateway off, and a method the app cannot complete must never
  /// end up on an order it then fails to place.
  PaymentMethod? resolve(String? chosen, List<String>? available) {
    final offeredMethods = offered(available);
    if (offeredMethods.isEmpty) return null;

    for (final method in offeredMethods) {
      if (method.id == chosen && method.supported) return method;
    }

    for (final method in offeredMethods) {
      if (method.id == defaultId && method.supported) return method;
    }

    for (final method in offeredMethods) {
      if (method.supported) return method;
    }
    return null;
  }
}

/// One gateway.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.title,
    required this.description,
    required this.supported,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      supported: json['supported'] == true,
    );
  }

  /// WooCommerce's gateway id — `cod`, `bacs`, `stripe`. **The only part
  /// that is not display copy**, and what goes on the order.
  final String id;

  /// May contain HTML, like everything from WordPress. Render through
  /// `plainText()`.
  final String title;
  final String description;

  /// Whether this app can carry it through to a placed order. False for
  /// anything needing a redirect or a native SDK, which is card and PayPal —
  /// their own phase.
  final bool supported;
}

import 'currency.dart';
import 'money.dart';
import 'product.dart';

/// Quantity bounds the server enforces for one cart line.
class QuantityLimits {
  const QuantityLimits({
    required this.minimum,
    required this.maximum,
    required this.multipleOf,
    required this.editable,
  });

  factory QuantityLimits.fromJson(Map<String, dynamic> json) {
    return QuantityLimits(
      minimum: (json['minimum'] as num?)?.toInt() ?? 1,
      maximum: (json['maximum'] as num?)?.toInt() ?? 9999,
      multipleOf: (json['multiple_of'] as num?)?.toInt() ?? 1,
      editable: json['editable'] as bool? ?? true,
    );
  }

  static const unbounded = QuantityLimits(
    minimum: 1,
    maximum: 9999,
    multipleOf: 1,
    editable: true,
  );

  final int minimum;
  final int maximum;
  final int multipleOf;

  /// False for products sold individually, where the stepper must be hidden.
  final bool editable;

  /// Clamps a requested quantity to what the server would accept.
  ///
  /// Steps **down** to the nearest allowed multiple rather than to the
  /// nearest one, so tapping + on a six-pack-only item never silently
  /// charges for more than was asked for. The minimum still wins, so a
  /// request below it is raised rather than dropped to zero.
  int clamp(int requested) {
    final stepped = multipleOf <= 1
        ? requested
        : (requested ~/ multipleOf) * multipleOf;
    return stepped.clamp(minimum, maximum);
  }
}

/// One add-on chosen on a cart line, as the plugin's extension reports it.
///
/// Read from `extensions['food-menu-pro']`, **not** from [CartItem.itemData]:
/// that list is the website's own display copy, with the quantity baked into
/// the string as `x2` and no ids or prices at all. See `CONTEXT.md`.
class CartAddon {
  const CartAddon({
    required this.groupId,
    required this.groupTitle,
    required this.fieldType,
    required this.optionId,
    required this.value,
    required this.quantity,
    required this.price,
    required this.priceSingle,
  });

  factory CartAddon.fromJson(Map<String, dynamic> json, Currency currency) {
    return CartAddon(
      // Both ids are null for a `text` group, and when the group or label was
      // reworded after this line went into the cart. The line is still real,
      // so the app renders it and simply cannot offer "edit".
      groupId: json['group_id'] as String?,
      groupTitle: json['group_title'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? '',
      optionId: json['option_id'] as String?,
      value: json['value'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: Money.parseOrZero(json['price'], currency),
      priceSingle: Money.parseOrZero(json['price_single'], currency),
    );
  }

  /// The group's id, as `GET fmp/v1/app/products/{id}/addons` publishes it.
  final String? groupId;
  final String groupTitle;

  /// `dropdown`, `checkbox`, `radio`, `text` or `textarea`.
  final String fieldType;
  final String? optionId;

  /// The chosen option's label, or the text the customer typed.
  final String value;

  /// How many of this option. One unless the group carries a stepper.
  final int quantity;

  /// What this add-on adds, with its quantity already included.
  final Money price;

  /// What one of this option adds.
  final Money priceSingle;

  /// The line to show under the dish name, e.g. `Mushrooms ×2`.
  String get label => quantity > 1 ? '$value ×$quantity' : value;
}

/// The add-ons on one cart line, and what they did to its price.
class CartItemAddons {
  const CartItemAddons({
    required this.addons,
    required this.addonsTotal,
    required this.addonsTotalCharged,
    required this.basePrice,
    required this.currency,
  });

  /// A line with no add-ons, which is most of them.
  static CartItemAddons none(Currency currency) => CartItemAddons(
        addons: const [],
        addonsTotal: Money.zero(currency),
        addonsTotalCharged: Money.zero(currency),
        basePrice: Money.zero(currency),
        currency: currency,
      );

  /// Reads the block off a cart item, tolerating its absence at every level.
  ///
  /// A store whose plugin predates task 4.3 sends `extensions: {}`, and the
  /// line then has no add-ons rather than failing to parse.
  static CartItemAddons fromItemJson(
    Map<String, dynamic> json,
    Currency fallbackCurrency,
  ) {
    final extensions = json['extensions'];
    if (extensions is! Map) return none(fallbackCurrency);

    final block = extensions['food-menu-pro'];
    if (block is! Map) return none(fallbackCurrency);

    final map = block.cast<String, dynamic>();
    // The currency keys are inline here, the way the Store API writes them
    // everywhere — unlike the add-ons endpoint, which nests them.
    final currency = map.containsKey('currency_code')
        ? Currency.fromJson(map)
        : fallbackCurrency;

    final rows = map['addons'];

    return CartItemAddons(
      addons: rows is List
          ? rows
              .whereType<Map>()
              .map((e) => CartAddon.fromJson(e.cast<String, dynamic>(), currency))
              .toList(growable: false)
          : const [],
      addonsTotal: Money.parseOrZero(map['addons_total'], currency),
      addonsTotalCharged:
          Money.parseOrZero(map['addons_total_charged'], currency),
      basePrice: Money.parseOrZero(map['base_price'], currency),
      currency: currency,
    );
  }

  final List<CartAddon> addons;

  /// The add-on prices added up, before any discount. What the order line
  /// records, and what the website calls "Addons price".
  final Money addonsTotal;

  /// The add-on part of the unit price **actually charged**. Differs from
  /// [addonsTotal] when the store discounts add-ons.
  final Money addonsTotalCharged;

  /// The dish part of the unit price actually charged. With
  /// [addonsTotalCharged] it sums to the line's `prices.price`.
  final Money basePrice;

  final Currency currency;

  bool get isEmpty => addons.isEmpty;
  bool get isNotEmpty => addons.isNotEmpty;

  /// The add-ons as one line of text, for the cart row's subtitle.
  String get summary => addons.map((a) => a.label).join(' · ');
}

/// A name/value pair the server attaches to a cart line.
///
/// The plugin's own display copy, written through `woocommerce_get_item_data`
/// and returned verbatim. **Prefer [CartItem.addons]** for anything to do with
/// add-ons — this carries no ids and no prices. Values may contain HTML.
class CartItemData {
  const CartItemData({required this.name, required this.value});

  factory CartItemData.fromJson(Map<String, dynamic> json) {
    return CartItemData(
      name: json['name'] as String? ?? json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  final String name;
  final String value;
}

/// Per-line money. Separate from the cart's own totals.
class CartItemTotals {
  const CartItemTotals({
    required this.lineSubtotal,
    required this.lineTotal,
    required this.currency,
  });

  factory CartItemTotals.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromJson(json);
    return CartItemTotals(
      lineSubtotal: Money.parseOrZero(json['line_subtotal'], currency),
      lineTotal: Money.parseOrZero(json['line_total'], currency),
      currency: currency,
    );
  }

  /// Before discounts.
  final Money lineSubtotal;

  /// After discounts. What this line contributes to the cart total.
  final Money lineTotal;
  final Currency currency;
}

/// One line in the cart.
///
/// Identified by [key], not by product [id]: the same product added twice with
/// different add-ons is two lines sharing one id, so every update and remove
/// must address the key.
class CartItem {
  const CartItem({
    required this.key,
    required this.id,
    required this.quantity,
    required this.name,
    required this.prices,
    required this.totals,
    required this.images,
    required this.itemData,
    this.variation = const [],
    required this.quantityLimits,
    required this.shortDescription,
    required this.addons,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final totals = CartItemTotals.fromJson(
      (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    return CartItem(
      key: json['key'] as String? ?? '',
      id: (json['id'] as num).toInt(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      prices: ProductPrices.fromJson(
        (json['prices'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      totals: totals,
      images: ((json['images'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProductImage.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      itemData: ((json['item_data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CartItemData.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      // `attribute` is the store's label for it, `value` the chosen term.
      variation: ((json['variation'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) {
            final entry = e.cast<String, dynamic>();
            return CartItemData(
              name: entry['attribute'] as String? ?? '',
              value: entry['value'] as String? ?? '',
            );
          })
          .where((d) => d.value.isNotEmpty)
          .toList(growable: false),
      quantityLimits: json['quantity_limits'] is Map
          ? QuantityLimits.fromJson(
              (json['quantity_limits'] as Map).cast<String, dynamic>(),
            )
          : QuantityLimits.unbounded,
      shortDescription: json['short_description'] as String? ?? '',
      addons: CartItemAddons.fromItemJson(json, totals.currency),
    );
  }

  /// The server's line identifier. Use this, not [id], to update or remove.
  final String key;

  /// The product id. Not unique within a cart.
  final int id;
  final int quantity;
  final String name;
  final ProductPrices prices;
  final CartItemTotals totals;
  final List<ProductImage> images;

  /// The server's own display copy for the line. See [CartItemData].
  final List<CartItemData> itemData;

  /// The attributes that picked this line's variation — "Size: Small".
  ///
  /// **Not in `item_data`**, which the Store API leaves empty for a variable
  /// product, so without this two sizes of the same dish are two identical
  /// looking lines.
  final List<CartItemData> variation;
  final QuantityLimits quantityLimits;
  final String shortDescription;

  /// The add-ons chosen on this line, with their price effect.
  final CartItemAddons addons;

  ProductImage? get primaryImage => images.isEmpty ? null : images.first;

  @override
  String toString() => 'CartItem($key, $name x$quantity)';
}

/// The cart's money block.
class CartTotals {
  const CartTotals({
    required this.totalItems,
    required this.totalPrice,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalFees,
    required this.currency,
    this.totalShipping,
  });

  factory CartTotals.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromJson(json);
    return CartTotals(
      totalItems: Money.parseOrZero(json['total_items'], currency),
      totalPrice: Money.parseOrZero(json['total_price'], currency),
      totalDiscount: Money.parseOrZero(json['total_discount'], currency),
      totalTax: Money.parseOrZero(json['total_tax'], currency),
      totalFees: Money.parseOrZero(json['total_fees'], currency),
      // Null until shipping has been calculated, which for pickup orders is
      // never — hence nullable rather than zero.
      totalShipping: Money.tryParse(json['total_shipping'], currency),
      currency: currency,
    );
  }

  /// Line items only, before discounts, fees, shipping and tax.
  final Money totalItems;

  /// The amount due.
  final Money totalPrice;
  final Money totalDiscount;
  final Money totalTax;
  final Money totalFees;
  final Money? totalShipping;
  final Currency currency;

  bool get hasDiscount => !totalDiscount.isZero;
}

/// What the store offers by way of tipping, and what the customer has chosen.
///
/// **A tip is an input, not arithmetic** (task 9.4). The website asks, writes
/// the answer to the session, and the plugin turns it into a cart **fee** on
/// every recalculation — so it reaches the order as a line item, with none of
/// the trouble task 9.3 found with the cart-level discount.
///
/// **No preset amounts**, because the plugin configures none: the settings say
/// which *kinds* of tip are allowed and where the form belongs, and the amount
/// is whatever the customer enters. Offering "10% / 15% / 20%" here would be
/// the app inventing a store policy.
class CartTip {
  const CartTip({
    required this.enabled,
    required this.allow,
    required this.where,
    required this.heading,
    required this.type,
    required this.fixed,
    required this.percentage,
  });

  static const none = CartTip(
    enabled: false,
    allow: [],
    where: 'both',
    heading: '',
    type: '',
    fixed: null,
    percentage: 0,
  );

  factory CartTip.fromJson(Map<String, dynamic> json, Currency currency) {
    final allow = json['allow'];

    return CartTip(
      enabled: json['enabled'] == true,
      allow: allow is List
          ? allow.map((e) => e.toString()).toList(growable: false)
          : const [],
      where: json['where'] as String? ?? 'both',
      heading: json['heading'] as String? ?? '',
      type: json['type'] as String? ?? '',
      fixed: Money.tryParse(json['fixed'], currency),
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
    );
  }

  final bool enabled;

  /// The kinds the store accepts: `fixed`, `percentage`, or both.
  final List<String> allow;

  /// Where the store shows its tip form: `cart`, `checkout` or `both`.
  final String where;

  /// The store's own prompt, already translated.
  final String heading;

  /// The kind currently on the cart, or empty for none.
  final String type;

  final Money? fixed;
  final int percentage;

  bool get allowsFixed => allow.contains('fixed');
  bool get allowsPercentage => allow.contains('percentage');

  /// Whether a tip is on the cart right now.
  bool get isSet =>
      (type == 'fixed' && (fixed?.minorUnits ?? 0) > 0) ||
      (type == 'percentage' && percentage > 0);

  bool showOn(String screen) => where == 'both' || where == screen;
}

/// The whole cart.
class Cart {
  const Cart({
    required this.items,
    required this.itemsCount,
    required this.totals,
    required this.needsPayment,
    required this.needsShipping,
    required this.shippingPackages,
    required this.paymentMethods,
    required this.errors,
    this.tip = CartTip.none,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CartItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      totals: CartTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      tip: _tip(json),
      needsPayment: json['needs_payment'] as bool? ?? false,
      needsShipping: json['needs_shipping'] as bool? ?? false,
      shippingPackages: ((json['shipping_rates'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ShippingPackage.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      paymentMethods: ((json['payment_methods'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      errors: ((json['errors'] as List?) ?? const [])
          .map((e) => e is Map ? (e['message']?.toString() ?? '') : e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// An empty cart, for the state before the first fetch.
  static Cart empty() => Cart(
        items: const [],
        itemsCount: 0,
        totals: CartTotals.fromJson(const {}),
        needsPayment: false,
        needsShipping: false,
        shippingPackages: const [],
        paymentMethods: const [],
        errors: const [],
      );

  final List<CartItem> items;

  /// Total units, i.e. the sum of quantities — not the number of lines.
  final int itemsCount;
  final CartTotals totals;
  final bool needsPayment;
  final bool needsShipping;

  /// What the store will deliver this cart for, per package (task 8.5).
  ///
  /// Empty for a pickup order, for a store running no shipping zone, and for
  /// an address no zone covers — the last of which is why an empty list is
  /// not the same as "no choice to make".
  final List<ShippingPackage> shippingPackages;

  /// Gateway ids that can pay for **this cart**, as WooCommerce works it out:
  /// a gateway can be enabled store-wide and still be unavailable here, over
  /// a country or an order total. The ids come with no words, which is what
  /// `GET fmp/v1/app/payment-methods` answers.
  final List<String> paymentMethods;

  /// Server-side complaints, e.g. a dish that went out of stock.
  final List<String> errors;

  /// Tipping, as this store has it set up (task 9.4).
  final CartTip tip;

  /// Reads the plugin's tip block off the cart's extensions.
  ///
  /// Absent on a store whose plugin predates it, which reads as "this store
  /// does not take tips" — the honest answer, since it cannot.
  static CartTip _tip(Map<String, dynamic> json) {
    final extensions = json['extensions'];
    if (extensions is! Map) return CartTip.none;

    final foodMenu = extensions['food-menu-pro'];
    if (foodMenu is! Map) return CartTip.none;

    final tip = foodMenu['tip'];
    if (tip is! Map) return CartTip.none;

    return CartTip.fromJson(
      tip.cast<String, dynamic>(),
      CartTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ).currency,
    );
  }

  bool get isEmpty => items.isEmpty;

  CartItem? itemByKey(String key) {
    for (final item in items) {
      if (item.key == key) return item;
    }
    return null;
  }

  @override
  String toString() =>
      'Cart(${items.length} lines, $itemsCount units, ${totals.totalPrice.format()})';
}

/// One shipment the store would send, with the ways it could send it.
///
/// WooCommerce splits a cart into packages when different lines ship from
/// different places or under different rules. A restaurant order is one
/// package in practice, so [name] is drawn only when there is more than one.
class ShippingPackage {
  const ShippingPackage({
    required this.packageId,
    required this.name,
    required this.rates,
  });

  factory ShippingPackage.fromJson(Map<String, dynamic> json) {
    return ShippingPackage(
      packageId: (json['package_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      rates: ((json['shipping_rates'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ShippingRate.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  /// What `cart/select-shipping-rate` is told, alongside a rate id.
  final int packageId;

  /// WooCommerce's own word, typically "Shipment".
  final String name;

  final List<ShippingRate> rates;

  /// The rate in force, which the server always marks for itself.
  ShippingRate? get selected {
    for (final rate in rates) {
      if (rate.selected) return rate;
    }
    return null;
  }
}

/// One way the store would deliver a package, at its own price.
class ShippingRate {
  const ShippingRate({
    required this.rateId,
    required this.name,
    required this.description,
    required this.deliveryTime,
    required this.price,
    required this.selected,
    required this.methodId,
  });

  factory ShippingRate.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromJson(json);

    return ShippingRate(
      rateId: json['rate_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deliveryTime: json['delivery_time'] as String? ?? '',
      price: Money.parseOrZero(json['price'], currency),
      selected: json['selected'] == true,
      methodId: json['method_id'] as String? ?? '',
    );
  }

  /// `flat_rate:1`, and what identifies this rate to the server.
  final String rateId;

  /// **The store's own words**, e.g. "Standard delivery". Never composed
  /// here: a store renames its methods and expects the app to follow.
  final String name;

  /// Extra words the method carries. Usually empty.
  final String description;

  /// The method's own estimate, when it has one. Usually empty — most
  /// methods carry no promise about time.
  final String deliveryTime;

  final Money price;
  final bool selected;

  /// `flat_rate`, `local_pickup`, `free_shipping`. Not branched on: a store
  /// can install a method this app has never heard of.
  final String methodId;

  bool get isFree => price.isZero;
}

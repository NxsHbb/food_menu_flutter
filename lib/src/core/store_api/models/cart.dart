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

/// The whole cart.
class Cart {
  const Cart({
    required this.items,
    required this.itemsCount,
    required this.totals,
    required this.needsPayment,
    required this.needsShipping,
    required this.errors,
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
      needsPayment: json['needs_payment'] as bool? ?? false,
      needsShipping: json['needs_shipping'] as bool? ?? false,
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
        errors: const [],
      );

  final List<CartItem> items;

  /// Total units, i.e. the sum of quantities — not the number of lines.
  final int itemsCount;
  final CartTotals totals;
  final bool needsPayment;
  final bool needsShipping;

  /// Server-side complaints, e.g. a dish that went out of stock.
  final List<String> errors;

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

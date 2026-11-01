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

/// A name/value pair the server attaches to a cart line.
///
/// This is where **product add-ons will surface** once Phase 4 lands: the Pro
/// plugin writes them through `woocommerce_get_item_data`, which the Store API
/// returns here verbatim. Values may contain HTML.
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
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      key: json['key'] as String? ?? '',
      id: (json['id'] as num).toInt(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      prices: ProductPrices.fromJson(
        (json['prices'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      totals: CartItemTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
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

  /// Add-ons and other per-line extras, once Phase 4 sends them.
  final List<CartItemData> itemData;
  final QuantityLimits quantityLimits;
  final String shortDescription;

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

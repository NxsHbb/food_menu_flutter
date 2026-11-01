import 'currency.dart';
import 'money.dart';

/// A product category as the Store API embeds it on a product.
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }

  final int id;
  final String name;
  final String slug;
}

/// One product image. `src` is the full-size URL; `thumbnail` is smaller.
class ProductImage {
  const ProductImage({
    required this.id,
    required this.src,
    required this.thumbnail,
    required this.alt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      src: json['src'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? json['src'] as String? ?? '',
      alt: json['alt'] as String? ?? '',
    );
  }

  final int id;
  final String src;
  final String thumbnail;
  final String alt;
}

/// The price block the Store API attaches to products and cart items.
class ProductPrices {
  const ProductPrices({
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.currency,
    this.priceRangeMin,
    this.priceRangeMax,
  });

  factory ProductPrices.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromJson(json);

    // Variable products send a range instead of a single meaningful price.
    Money? rangeMin;
    Money? rangeMax;
    final range = json['price_range'];
    if (range is Map<String, dynamic>) {
      rangeMin = Money.tryParse(range['min_amount'], currency);
      rangeMax = Money.tryParse(range['max_amount'], currency);
    }

    return ProductPrices(
      price: Money.parseOrZero(json['price'], currency),
      regularPrice: Money.parseOrZero(json['regular_price'], currency),
      salePrice: Money.parseOrZero(json['sale_price'], currency),
      currency: currency,
      priceRangeMin: rangeMin,
      priceRangeMax: rangeMax,
    );
  }

  /// What the customer pays now.
  final Money price;

  /// The pre-discount price. Equal to [price] when nothing is discounted.
  final Money regularPrice;
  final Money salePrice;
  final Currency currency;

  final Money? priceRangeMin;
  final Money? priceRangeMax;

  /// True when the regular price is worth showing struck through.
  ///
  /// Derived rather than trusting the product's `on_sale` flag, because the
  /// two can disagree: a scheduled sale that has lapsed still leaves
  /// `sale_price` populated.
  bool get isDiscounted => regularPrice.minorUnits > price.minorUnits;

  /// True for variable products, where a single price is misleading.
  bool get hasRange => priceRangeMin != null && priceRangeMax != null;
}

/// A menu item. The Store API calls it a product; the design calls it a dish.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.permalink,
    required this.type,
    required this.prices,
    required this.images,
    required this.categories,
    required this.description,
    required this.shortDescription,
    required this.isInStock,
    required this.isPurchasable,
    required this.hasOptions,
    required this.onSale,
    required this.averageRating,
    required this.reviewCount,
    required this.lowStockRemaining,
    required this.stockText,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      permalink: json['permalink'] as String? ?? '',
      type: json['type'] as String? ?? 'simple',
      prices: ProductPrices.fromJson(
        (json['prices'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      images: ((json['images'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProductImage.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProductCategory.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      description: json['description'] as String? ?? '',
      shortDescription: json['short_description'] as String? ?? '',
      isInStock: json['is_in_stock'] as bool? ?? true,
      isPurchasable: json['is_purchasable'] as bool? ?? true,
      // True when the product needs choices made before it can be added —
      // a variable product, or one with required add-on groups.
      hasOptions: json['has_options'] as bool? ?? false,
      onSale: json['on_sale'] as bool? ?? false,
      // Sent as a string, e.g. "4.50", not a number.
      averageRating: double.tryParse(json['average_rating']?.toString() ?? '') ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      lowStockRemaining: (json['low_stock_remaining'] as num?)?.toInt(),
      // The API supplies its own wording ("Out of stock", "Only 2 left in
      // stock"), already translated by the site. Preferred over inventing
      // copy the store owner cannot change.
      stockText: switch (json['stock_availability']) {
        final Map<dynamic, dynamic> m => m['text'] as String? ?? '',
        _ => '',
      },
    );
  }

  final int id;
  final String name;
  final String slug;
  final String permalink;

  /// `simple`, `variable`, `grouped`, `external`.
  final String type;
  final ProductPrices prices;
  final List<ProductImage> images;
  final List<ProductCategory> categories;

  /// Both description fields arrive as HTML and need rendering or stripping.
  final String description;
  final String shortDescription;

  final bool isInStock;
  final bool isPurchasable;
  final bool hasOptions;
  final bool onSale;
  final double averageRating;
  final int reviewCount;

  /// Non-null only when the store is set to warn at a low threshold.
  ///
  /// **Can be 0 on an out-of-stock product**, so never render it without
  /// checking [isInStock] first — see [lowStockWarning].
  final int? lowStockRemaining;

  /// The site's own stock wording, e.g. `Out of stock`. May be empty.
  final String stockText;

  /// How many are left, but only when that is worth saying.
  ///
  /// Guards the trap above: the API sends `low_stock_remaining: 0` alongside
  /// `is_in_stock: false`, which would otherwise render as "Only 0 left".
  int? get lowStockWarning {
    final remaining = lowStockRemaining;
    if (!isInStock || remaining == null || remaining <= 0) return null;
    return remaining;
  }

  /// True when the dish can be ordered at all.
  ///
  /// Note that `is_purchasable` stays **true** on a sold-out product, so it
  /// alone is not enough.
  bool get isOrderable => isPurchasable && isInStock;

  ProductImage? get primaryImage => images.isEmpty ? null : images.first;

  /// True when a tap can add this straight to the cart, with no choices and
  /// no trip to the detail screen.
  bool get canAddDirectly => isPurchasable && isInStock && !hasOptions;

  @override
  String toString() => 'Product($id, $name, ${prices.price.format()})';
}

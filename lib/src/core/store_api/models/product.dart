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

/// A food tag, e.g. Vegetarian or Spicy.
///
/// Backed by WooCommerce's `product_tag` taxonomy. Note this is **not** the
/// plugin's own `food-menu-tag` taxonomy, which is registered only for the
/// `food-menu` post type and so is unreachable in online-ordering mode.
class ProductTag {
  const ProductTag({required this.id, required this.name, required this.slug});

  factory ProductTag.fromJson(Map<String, dynamic> json) {
    return ProductTag(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }

  final int id;
  final String name;
  final String slug;
}

/// One ingredient or nutrition row on a dish.
///
/// Supplied by the Food Menu plugin through its `food-menu-pro` Store API
/// extension, not by WooCommerce. [value] and [unit] are both optional on the
/// admin side, so either can be empty — "Basil" with no amount is a valid row.
class FoodDataRow {
  const FoodDataRow({
    required this.id,
    required this.name,
    required this.value,
    required this.unit,
  });

  factory FoodDataRow.fromJson(Map<String, dynamic> json) {
    return FoodDataRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      // Sent as a string, because the admin field is free text.
      value: json['value']?.toString() ?? '',
      unit: json['unit'] as String? ?? '',
    );
  }

  final int id;
  final String name;
  final String value;
  final String unit;

  /// A row with no name has nothing to render.
  bool get isRenderable => name.isNotEmpty;

  /// "120 g", "540 kcal", or empty when no amount was entered.
  String get amount {
    if (value.isEmpty) return unit;
    return unit.isEmpty ? value : '$value $unit';
  }

  @override
  String toString() => 'FoodDataRow($name, $amount)';
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
    required this.tags,
    required this.ingredients,
    required this.nutrition,
    required this.description,
    required this.shortDescription,
    required this.isInStock,
    required this.isPurchasable,
    required this.hasOptions,
    required this.requiresChoices,
    required this.timed,
    required this.attributes,
    required this.variations,
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
      prices: _applyMenuDiscount(
        ProductPrices.fromJson(
          (json['prices'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        json,
      ),
      images: ((json['images'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProductImage.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProductCategory.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      tags: ((json['tags'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProductTag.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      ingredients: _foodData(json, 'ingredients'),
      nutrition: _foodData(json, 'nutrition'),
      description: json['description'] as String? ?? '',
      shortDescription: json['short_description'] as String? ?? '',
      isInStock: json['is_in_stock'] as bool? ?? true,
      isPurchasable: json['is_purchasable'] as bool? ?? true,
      // WooCommerce's own flag, which means a variable product and nothing
      // else. It knows nothing about add-ons — see [requiresChoices].
      hasOptions: json['has_options'] as bool? ?? false,
      requiresChoices: _flag(json, 'requires_choices'),
      timed: TimedAvailability.fromExtension(json),
      attributes: _list(json['attributes'], ProductAttribute.fromJson),
      variations: _list(json['variations'], ProductVariation.fromJson),
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

  /// Food tags, from `product_tag`. Often empty.
  final List<ProductTag> tags;

  /// Ingredients, from the plugin's Store API extension. Often empty.
  final List<FoodDataRow> ingredients;

  /// Nutrition facts, from the plugin's Store API extension. Often empty.
  final List<FoodDataRow> nutrition;

  /// Both description fields arrive as HTML and need rendering or stripping.
  final String description;
  final String shortDescription;

  final bool isInStock;
  final bool isPurchasable;
  final bool hasOptions;

  /// True when an add-on group must be answered before the dish can go in the
  /// cart, from the plugin's Store API extension.
  ///
  /// Separate from [hasOptions] because WooCommerce's flag covers variable
  /// products only; a *simple* dish with a required add-on group arrives with
  /// `has_options: false` and is still refused by the server if added blind.
  ///
  /// False on a site whose plugin predates the field, which leaves the old
  /// behaviour rather than hiding every quick add.
  final bool requiresChoices;

  /// Whether the store serves this dish at the moment, and what it asked for
  /// when it does not.
  ///
  /// Always served on a site whose plugin predates the field, which leaves
  /// the old behaviour rather than emptying a menu.
  final TimedAvailability timed;

  /// The dish's attributes. Only those with [ProductAttribute.hasVariations]
  /// pick a variation; the rest are descriptive and are not drawn.
  final List<ProductAttribute> attributes;

  /// One entry per combination the store actually made, with the terms that
  /// name it. **No prices here** — the Store API sends none, so the chosen
  /// variation is read back as a product of its own.
  final List<ProductVariation> variations;

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
  ///
  /// **A dish outside its hours is not orderable either** (task 8.3). Folded
  /// in here rather than checked at each call site, because the server
  /// refuses it at add-to-cart exactly as it refuses a sold-out one, and
  /// every screen that already respects stock then respects the clock.
  bool get isOrderable => isPurchasable && isInStock && timed.available;

  /// Why the dish cannot be ordered, in the store's own words where it has
  /// them. Empty while it can be.
  ///
  /// Stock comes first: a dish that is both sold out and outside its hours
  /// is sold out, and saying so is the more final answer.
  String get unavailableReason {
    if (isOrderable) return '';
    if (!isInStock && stockText.isNotEmpty) return stockText;
    if (!timed.available && timed.note.isNotEmpty) return timed.note;

    return 'Unavailable';
  }

  /// True when the store wants this dish off the menu entirely right now.
  ///
  /// The list screens drop it; nothing else needs to know. A dish opened
  /// from a link or a favourite still draws, unorderable and saying why,
  /// which beats a dead end.
  bool get hiddenByStore => !timed.available && timed.behavior == TimedBehavior.disappear;

  ProductImage? get primaryImage => images.isEmpty ? null : images.first;

  /// True when there is any food data worth giving a section to.
  bool get hasFoodData => ingredients.isNotEmpty || nutrition.isNotEmpty;

  /// Folds the plugin's automatic discount into the Store API's own prices.
  ///
  /// **Task 9.1.** The discount reaches the website through
  /// `woocommerce_get_price_html` and the cart through
  /// `woocommerce_add_cart_item`, and never the price object `/products`
  /// serves — so a dish card read the full price and the cart then charged
  /// less, with nothing in between to explain it.
  ///
  /// Folded in **here** rather than drawn as a third price somewhere: a card,
  /// a row and the detail screen already know how to put a struck-through
  /// price beside a charged one, because a WooCommerce sale needs exactly
  /// that. Setting [ProductPrices.price] and [ProductPrices.regularPrice] to
  /// the plugin's pair makes every one of those surfaces right at once, and
  /// `isDiscounted` keeps meaning what it meant.
  ///
  /// **The struck price is `was`, not the regular price.** A dish at 11.25
  /// reduced to 9.75 and then discounted 15% is charged 8.29, and 9.75 is
  /// what is crossed out — the 11.25 was already crossed out before this
  /// discount existed, and showing it would overstate the saving.
  ///
  /// Absent on a store whose plugin predates this, which leaves the Store
  /// API's own prices exactly as they were.
  static ProductPrices _applyMenuDiscount(
    ProductPrices prices,
    Map<String, dynamic> json,
  ) {
    final extensions = json['extensions'];
    if (extensions is! Map) return prices;

    final foodMenu = extensions['food-menu-pro'];
    if (foodMenu is! Map) return prices;

    final discount = foodMenu['discount'];
    if (discount is! Map || discount['active'] != true) return prices;

    final charged = Money.tryParse(discount['price'], prices.currency);
    final was = Money.tryParse(discount['was'], prices.currency);

    // Both or neither. A charged price with nothing to strike through is a
    // price cut nobody can see, and a struck price with nothing charged is a
    // dish with no price at all.
    if (charged == null || was == null) return prices;

    return ProductPrices(
      price: charged,
      regularPrice: was,
      salePrice: charged,
      currency: prices.currency,
      priceRangeMin: prices.priceRangeMin,
      priceRangeMax: prices.priceRangeMax,
    );
  }

  /// Reads one boolean out of the plugin's Store API extension block.
  ///
  /// Missing at every level on a site running an older plugin, and on any
  /// non-WooCommerce response, so absence is false rather than an error.
  static bool _flag(Map<String, dynamic> json, String key) {
    final extensions = json['extensions'];
    if (extensions is! Map) return false;

    final foodMenu = extensions['food-menu-pro'];
    if (foodMenu is! Map) return false;

    return foodMenu[key] == true;
  }

  /// Reads one list out of the plugin's Store API extension block.
  ///
  /// Absent on a site whose plugin predates the change, and absent from any
  /// non-WooCommerce response, so every level is tolerated as missing rather
  /// than assumed.
  static List<FoodDataRow> _foodData(Map<String, dynamic> json, String key) {
    final extensions = json['extensions'];
    if (extensions is! Map) return const [];

    final foodMenu = extensions['food-menu-pro'];
    if (foodMenu is! Map) return const [];

    final rows = foodMenu[key];
    if (rows is! List) return const [];

    return rows
        .whereType<Map>()
        .map((e) => FoodDataRow.fromJson(e.cast<String, dynamic>()))
        .where((row) => row.isRenderable)
        .toList(growable: false);
  }

  /// The attributes a customer has to answer, in the order the store set.
  List<ProductAttribute> get variableAttributes => [
        for (final attribute in attributes)
          if (attribute.hasVariations && attribute.terms.isNotEmpty) attribute,
      ];

  /// True when ordering this dish means choosing something first.
  ///
  /// Either half is enough: a variable product needs a variation, and a dish
  /// with a required add-on group needs an answer. Both lead to the dish
  /// screen rather than to the cart.
  bool get needsChoices => hasOptions || requiresChoices;

  /// True when a tap can add this straight to the cart, with no choices and
  /// no trip to the detail screen.
  bool get canAddDirectly => isOrderable && !needsChoices;

  @override
  String toString() => 'Product($id, $name, ${prices.price.format()})';
}

/// One of a dish's attributes — "Size", "Crust".
class ProductAttribute {
  const ProductAttribute({
    required this.name,
    required this.taxonomy,
    required this.hasVariations,
    required this.terms,
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      name: json['name'] as String? ?? '',
      taxonomy: json['taxonomy'] as String? ?? '',
      hasVariations: json['has_variations'] == true,
      terms: _list(json['terms'], AttributeTerm.fromJson),
    );
  }

  /// The label as the store wrote it, and **the key `cart/add-item` takes** —
  /// it sanitises the name to the variation's own meta key, so `Size` and
  /// `size` both resolve.
  ///
  /// There is no separate human label to fall back on. A store that names an
  /// attribute `pa_size` has that on its own website too.
  final String name;

  /// Empty for a *custom* attribute, which is the common case in a restaurant
  /// — typed into the product rather than registered as a taxonomy. Such an
  /// attribute has `id: 0` everywhere, which is why nothing here matches on
  /// ids.
  final String taxonomy;

  /// Whether answering this picks a variation. False means it is descriptive.
  final bool hasVariations;

  final List<AttributeTerm> terms;
}

/// One choice within an attribute — "Large".
class AttributeTerm {
  const AttributeTerm({required this.name, required this.slug});

  factory AttributeTerm.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';

    return AttributeTerm(
      name: name,
      // For a custom attribute the slug **is** the name, which is also what a
      // variation stores as its value.
      slug: json['slug'] as String? ?? name,
    );
  }

  /// What the customer reads.
  final String name;

  /// What a variation's attribute value is matched against.
  final String slug;
}

/// One combination the store made, and the terms that name it.
class ProductVariation {
  const ProductVariation({required this.id, required this.attributes});

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    final raw = json['attributes'];
    final attributes = <String, String>{};

    if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        final name = entry['name'] as String? ?? '';
        if (name.isEmpty) continue;

        // Null is WooCommerce's "any": this variation serves every term of
        // that attribute. Kept as an empty string, and treated as a wildcard
        // where it is matched.
        attributes[name] = entry['value'] as String? ?? '';
      }
    }

    return ProductVariation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      attributes: attributes,
    );
  }

  /// The variation's own product id — what the cart line reports, and what to
  /// read back for its price and stock.
  final int id;

  /// Attribute name to the term slug it is fixed to. An empty value is "any".
  final Map<String, String> attributes;
}

/// Reads a list of maps into models, dropping anything that is not a map.
List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) read) {
  if (raw is! List) return const [];

  return raw
      .whereType<Map>()
      .map((e) => read(e.cast<String, dynamic>()))
      .toList(growable: false);
}

/// What a store asks for when it is not serving a dish.
enum TimedBehavior {
  /// Draw it, unorderable, with the store's own words for why.
  disable,

  /// Take it off the menu until it is served again.
  disappear;

  static TimedBehavior fromName(String? raw) =>
      raw == 'disappear' ? TimedBehavior.disappear : TimedBehavior.disable;
}

/// Whether the store serves a dish at this moment (task 8.3).
///
/// Timed rules are the plugin's own — "breakfast until eleven", "off the menu
/// on Mondays" — and the website hides or greys the dish per
/// `fmp_timed_products_behavior`. Before this, the app offered a breakfast
/// dish at nine at night and let the server refuse it at add-to-cart.
///
/// **Composed server-side.** [note] is the same text the website's badge
/// shows, already translated and in the store's own date and time formats, so
/// the app cannot word it differently from the web page.
class TimedAvailability {
  const TimedAvailability({
    required this.available,
    required this.behavior,
    required this.note,
  });

  /// The state of a dish on a site that says nothing: served, and no words
  /// about it. Keeps a menu working against a plugin predating the field.
  static const always = TimedAvailability(
    available: true,
    behavior: TimedBehavior.disable,
    note: '',
  );

  /// Reads the block out of the plugin's Store API extension.
  factory TimedAvailability.fromExtension(Map<String, dynamic> json) {
    final extensions = json['extensions'];
    if (extensions is! Map) return always;

    final foodMenu = extensions['food-menu-pro'];
    if (foodMenu is! Map) return always;

    final timed = foodMenu['timed'];
    if (timed is! Map) return always;

    return TimedAvailability(
      // Absent means served: a half-written payload must not empty a menu.
      available: timed['available'] != false,
      behavior: TimedBehavior.fromName(timed['behavior'] as String?),
      note: timed['note'] as String? ?? '',
    );
  }

  /// False when the kitchen will not make this right now.
  final bool available;

  /// Hide it, or show it greyed. The store's choice, not the app's.
  final TimedBehavior behavior;

  /// The store's own words: "Unavailable", "Will be Available: 8:00 am –
  /// 11:00 am", or empty when there is nothing worth saying — which includes
  /// every dish no rule covers.
  final String note;

  @override
  String toString() => 'TimedAvailability($available, ${behavior.name}, $note)';
}

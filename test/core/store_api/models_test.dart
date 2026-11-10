import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/cart.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';

/// Loads a fixture captured from the real dev site, so these tests fail if
/// the Store API's shape changes rather than if invented JSON changes.
Map<String, dynamic> fixture(String name) {
  final file = File('test/fixtures/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('Product', () {
    test('parses a simple product from a real payload', () {
      final product = Product.fromJson(fixture('product_simple'));

      expect(product.id, isPositive);
      expect(product.name, 'Iced Latte');
      expect(product.type, 'simple');
      expect(product.isInStock, isTrue);
      expect(product.isPurchasable, isTrue);
      expect(product.hasOptions, isFalse);
      expect(product.canAddDirectly, isTrue);
    });

    test('reads the price in major units, not minor', () {
      final product = Product.fromJson(fixture('product_simple'));

      // Seeded at $3.95, which the API sends as "395".
      expect(product.prices.price.format(), r'$3.95');
      expect(product.prices.price.minorUnits, 395);
    });

    test('detects a discount from the prices, not the on_sale flag', () {
      final product = Product.fromJson(fixture('product_on_sale'));

      expect(product.prices.isDiscounted, isTrue);
      expect(product.prices.price.format(), r'$4.95');
      expect(product.prices.regularPrice.format(), r'$5.95');
      expect(
        product.prices.regularPrice.minorUnits,
        greaterThan(product.prices.price.minorUnits),
      );
    });

    test('keeps embedded categories', () {
      final product = Product.fromJson(fixture('product_on_sale'));

      expect(product.categories, isNotEmpty);
      expect(product.categories.first.name, 'Desserts');
      expect(product.categories.first.slug, 'desserts');
    });

    test('survives a product with no images', () {
      final product = Product.fromJson(fixture('product_simple'));

      expect(product.images, isEmpty);
      expect(product.primaryImage, isNull);
    });

    test('reads average_rating even though it arrives as a string', () {
      final product = Product.fromJson({
        'id': 1,
        'name': 'Test',
        'prices': const {'price': '100', 'currency_minor_unit': 2},
        'average_rating': '4.50',
      });

      expect(product.averageRating, closeTo(4.5, 0.001));
    });

    test('treats a product with options as needing the detail screen', () {
      final product = Product.fromJson({
        'id': 2,
        'name': 'Pizza',
        'type': 'variable',
        'prices': const {'price': '900', 'currency_minor_unit': 2},
        'has_options': true,
      });

      expect(product.canAddDirectly, isFalse);
    });

    test('reads requires_choices out of the plugin extension', () {
      final product = Product.fromJson({
        'id': 25,
        'name': 'Fresh Lemonade',
        'prices': const {'price': '350', 'currency_minor_unit': 2},
        // A *simple* dish: WooCommerce says it needs nothing chosen, and the
        // plugin says a required add-on group disagrees.
        'has_options': false,
        'extensions': const {
          'food-menu-pro': {'requires_choices': true},
        },
      });

      expect(product.requiresChoices, isTrue);
      expect(product.needsChoices, isTrue);
      expect(product.canAddDirectly, isFalse);
    });

    test('a dish with only optional add-ons stays one-tap addable', () {
      final product = Product.fromJson({
        'id': 14,
        'name': 'Margherita',
        'prices': const {'price': '900', 'currency_minor_unit': 2},
        'extensions': const {
          'food-menu-pro': {'requires_choices': false},
        },
      });

      expect(product.canAddDirectly, isTrue);
    });

    test('an older plugin, with no flag at all, leaves the quick add alone',
        () {
      final product = Product.fromJson({
        'id': 14,
        'name': 'Margherita',
        'prices': const {'price': '900', 'currency_minor_unit': 2},
      });

      expect(product.requiresChoices, isFalse);
      expect(product.canAddDirectly, isTrue);
    });

    test('a sold-out dish is never addable from a card', () {
      final product = Product.fromJson({
        'id': 31,
        'name': 'Sold Out Special',
        'prices': const {'price': '900', 'currency_minor_unit': 2},
        // The trap `isOrderable` exists for: still purchasable, out of stock.
        'is_purchasable': true,
        'is_in_stock': false,
      });

      expect(product.needsChoices, isFalse);
      expect(product.canAddDirectly, isFalse);
    });

    test('parses a variable product price range', () {
      final prices = ProductPrices.fromJson(const {
        'price': '900',
        'regular_price': '900',
        'sale_price': '900',
        'currency_minor_unit': 2,
        'currency_code': 'USD',
        'currency_prefix': r'$',
        'price_range': {'min_amount': '900', 'max_amount': '1500'},
      });

      expect(prices.hasRange, isTrue);
      expect(prices.priceRangeMin!.format(), r'$9.00');
      expect(prices.priceRangeMax!.format(), r'$15.00');
    });
  });

  group('Cart', () {
    test('parses a real cart payload', () {
      final cart = Cart.fromJson(fixture('cart_with_item'));

      expect(cart.isEmpty, isFalse);
      expect(cart.items, hasLength(1));
      expect(cart.itemsCount, 2);
      expect(cart.errors, isEmpty);
    });

    test('line total reflects quantity', () {
      final cart = Cart.fromJson(fixture('cart_with_item'));
      final item = cart.items.single;

      // 2 x $3.95
      expect(item.quantity, 2);
      expect(item.prices.price.format(), r'$3.95');
      expect(item.totals.lineTotal.format(), r'$7.90');
    });

    test('cart total matches the line totals', () {
      final cart = Cart.fromJson(fixture('cart_with_item'));

      expect(cart.totals.totalPrice.format(), r'$7.90');
      expect(cart.totals.hasDiscount, isFalse);
    });

    test('shipping stays null until it is calculated', () {
      final cart = Cart.fromJson(fixture('cart_with_item'));

      // A pickup order never calculates shipping, so this must not read as
      // a zero charge.
      expect(cart.totals.totalShipping, isNull);
    });

    test('addresses lines by key, since one product can be two lines', () {
      final cart = Cart.fromJson(fixture('cart_with_item'));
      final key = cart.items.single.key;

      expect(key, isNotEmpty);
      expect(cart.itemByKey(key), isNotNull);
      expect(cart.itemByKey('nope'), isNull);
    });

    test('exposes quantity limits', () {
      final cart = Cart.fromJson(fixture('cart_with_item'));
      final limits = cart.items.single.quantityLimits;

      expect(limits.minimum, 1);
      expect(limits.editable, isTrue);
      expect(limits.clamp(0), 1);
      expect(limits.clamp(100000), limits.maximum);
    });

    test('clamp respects multiple_of', () {
      const limits = QuantityLimits(
        minimum: 2,
        maximum: 12,
        multipleOf: 2,
        editable: true,
      );

      expect(limits.clamp(5), 4);
      expect(limits.clamp(1), 2);
      expect(limits.clamp(99), 12);
    });

    test('an empty cart parses from nothing', () {
      final cart = Cart.empty();

      expect(cart.isEmpty, isTrue);
      expect(cart.itemsCount, 0);
      expect(cart.totals.totalPrice.isZero, isTrue);
    });

    test('collects server-side errors', () {
      final cart = Cart.fromJson(const {
        'items': [],
        'items_count': 0,
        'totals': {'total_price': '0', 'currency_minor_unit': 2},
        'errors': [
          {'code': 'out_of_stock', 'message': 'Lamb Biryani is out of stock.'},
        ],
      });

      expect(cart.errors, ['Lamb Biryani is out of stock.']);
    });

    test('item_data carries add-on lines when present', () {
      final item = CartItem.fromJson(const {
        'key': 'abc',
        'id': 5,
        'quantity': 1,
        'name': 'Double Smash',
        'prices': {'price': '1390', 'currency_minor_unit': 2},
        'totals': {'line_total': '1390', 'currency_minor_unit': 2},
        'item_data': [
          {'name': 'Extra cheese', 'value': 'Yes (+\$1.00)'},
        ],
      });

      expect(item.itemData, hasLength(1));
      expect(item.itemData.single.name, 'Extra cheese');
    });
  });
}

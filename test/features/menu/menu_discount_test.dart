import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';

/// Task 9.1: the plugin's automatic discount never reached the price object
/// the Store API serves, so the menu quoted full price and the cart then
/// charged less.
void main() {
  Map<String, dynamic> productJson({
    Map<String, dynamic>? discount,
    String price = '975',
    String regular = '1125',
    String sale = '975',
  }) =>
      {
        'id': 19,
        'name': 'Crispy Chicken Burger',
        'prices': {
          'price': price,
          'regular_price': regular,
          'sale_price': sale,
          'currency_code': 'USD',
          'currency_symbol': r'$',
          'currency_minor_unit': 2,
          'currency_decimal_separator': '.',
          'currency_thousand_separator': ',',
          'currency_prefix': r'$',
          'currency_suffix': '',
        },
        if (discount != null)
          'extensions': {
            'food-menu-pro': {'discount': discount},
          },
      };

  test('a discounted dish charges the plugin price and strikes the old one',
      () {
    final product = Product.fromJson(
      productJson(
        discount: {
          'active': true,
          'percentage': 15,
          'price': '829',
          'was': '975',
        },
      ),
    );

    expect(product.prices.price.format(), r'$8.29');
    expect(product.prices.regularPrice.format(), r'$9.75');
    expect(product.prices.isDiscounted, isTrue);
  });

  test('the struck price is what was charged, not the regular price', () {
    // 11.25 reduced to 9.75 and then discounted 15%. The 11.25 was already
    // crossed out before this discount existed; showing it would overstate
    // the saving.
    final product = Product.fromJson(
      productJson(
        discount: {
          'active': true,
          'percentage': 15,
          'price': '829',
          'was': '975',
        },
      ),
    );

    expect(product.prices.regularPrice.format(), isNot(r'$11.25'));
  });

  test('an inactive discount leaves the sale price alone', () {
    final product = Product.fromJson(
      productJson(
        discount: {
          'active': false,
          'percentage': 0,
          'price': null,
          'was': null,
        },
      ),
    );

    expect(product.prices.price.format(), r'$9.75');
    expect(product.prices.regularPrice.format(), r'$11.25');
    expect(product.prices.isDiscounted, isTrue);
  });

  test('an older plugin sends no extension, and nothing changes', () {
    final product = Product.fromJson(productJson());

    expect(product.prices.price.format(), r'$9.75');
    expect(product.prices.regularPrice.format(), r'$11.25');
  });

  test('half a discount is no discount', () {
    // A charged price with nothing to strike through is a price cut nobody
    // can see; a struck price with nothing charged is a dish with no price.
    final product = Product.fromJson(
      productJson(
        discount: {'active': true, 'percentage': 15, 'price': '829'},
      ),
    );

    expect(product.prices.price.format(), r'$9.75');
  });

  test('an undiscounted dish is not made to look discounted', () {
    final product = Product.fromJson(
      productJson(price: '1390', regular: '1390', sale: '1390'),
    );

    expect(product.prices.isDiscounted, isFalse);
  });
}

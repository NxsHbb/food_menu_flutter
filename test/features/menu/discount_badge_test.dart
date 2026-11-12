import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';

/// Task 9.2: the store's own "x% off" badge, and where it asked for it.
void main() {
  Product productWith(Map<String, dynamic>? discount) => Product.fromJson({
        'id': 18,
        'name': 'Double Smash',
        'prices': {
          'price': '1390',
          'regular_price': '1390',
          'sale_price': '1390',
          'currency_code': 'USD',
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
      });

  Map<String, dynamic> discount({
    bool active = true,
    String scope = 'everywhere',
    String label = 'Discount 15%',
    String short = '15% off',
  }) =>
      {
        'active': active,
        'percentage': 15,
        'price': '1182',
        'was': '1390',
        'badge': {'scope': scope, 'label': label, 'short': short},
      };

  test('everywhere shows on a card and on the dish screen', () {
    final d = productWith(discount()).discount;

    expect(d.showInList, isTrue);
    expect(d.showOnDetail, isTrue);
    expect(d.short, '15% off');
    expect(d.label, 'Discount 15%');
  });

  test('product_page shows on the dish screen only', () {
    final d = productWith(discount(scope: 'detail')).discount;

    expect(d.showInList, isFalse);
    expect(d.showOnDetail, isTrue);
  });

  test('an unrecognised setting shows nothing, as the website shows nothing',
      () {
    // `fmp_discount_badge_display` is `product_page` or `everywhere`. The
    // plugin reports any third value as `none`, because the website's own
    // two badge paths both return early on one.
    final d = productWith(discount(scope: 'all')).discount;

    expect(d.scope, DiscountBadgeScope.none);
    expect(d.showInList, isFalse);
    expect(d.showOnDetail, isFalse);
  });

  test('no discount, no badge, whatever the scope says', () {
    final d = productWith(
      discount(active: false, label: '', short: ''),
    ).discount;

    expect(d.showInList, isFalse);
    expect(d.showOnDetail, isFalse);
  });

  test('a scope with no words to say is not drawn', () {
    // The store asked for a badge and the plugin had no message for this
    // dish. An empty pill is worse than none.
    final d = productWith(discount(label: '', short: '')).discount;

    expect(d.showInList, isFalse);
    expect(d.showOnDetail, isFalse);
  });

  test('an older plugin sends no discount block at all', () {
    final d = productWith(null).discount;

    expect(d.active, isFalse);
    expect(d.scope, DiscountBadgeScope.none);
  });
}

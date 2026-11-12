import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/cart.dart';
import 'package:food_menu/src/core/store_api/models/currency.dart';

/// Task 9.4: a tip is an input, and the store decides which kinds it takes
/// and where it asks.
void main() {
  CartTip tipFrom(Map<String, dynamic> json) =>
      CartTip.fromJson(json, Currency.fallback);

  Map<String, dynamic> cartJson(Map<String, dynamic>? tip) => {
        'items': <dynamic>[],
        'items_count': 0,
        'totals': {
          'total_price': '1495',
          'currency_code': 'USD',
          'currency_minor_unit': 2,
          'currency_decimal_separator': '.',
          'currency_thousand_separator': ',',
          'currency_prefix': r'$',
          'currency_suffix': '',
        },
        if (tip != null)
          'extensions': {
            'food-menu-pro': {'tip': tip},
          },
      };

  group('what the store offers', () {
    test('both kinds, when it allows both', () {
      final tip = tipFrom({
        'enabled': true,
        'allow': ['fixed', 'percentage'],
      });

      expect(tip.allowsFixed, isTrue);
      expect(tip.allowsPercentage, isTrue);
    });

    test('one kind is one kind', () {
      final tip = tipFrom({
        'enabled': true,
        'allow': ['percentage'],
      });

      expect(tip.allowsFixed, isFalse);
      expect(tip.allowsPercentage, isTrue);
    });

    test('where it asks is honoured on both screens', () {
      expect(tipFrom({'where': 'both'}).showOn('checkout'), isTrue);
      expect(tipFrom({'where': 'both'}).showOn('cart'), isTrue);
      expect(tipFrom({'where': 'cart'}).showOn('checkout'), isFalse);
      expect(tipFrom({'where': 'checkout'}).showOn('cart'), isFalse);
    });

    test("the store's own prompt comes through", () {
      final tip = tipFrom({'heading': 'Look after the kitchen?'});

      expect(tip.heading, 'Look after the kitchen?');
    });
  });

  group('what is on the cart', () {
    test('a percentage tip', () {
      final tip = tipFrom({
        'enabled': true,
        'allow': ['percentage'],
        'type': 'percentage',
        'percentage': 15,
        'fixed': '0',
      });

      expect(tip.isSet, isTrue);
      expect(tip.percentage, 15);
    });

    test('a fixed tip, in minor units like every other amount', () {
      final tip = tipFrom({
        'enabled': true,
        'allow': ['fixed'],
        'type': 'fixed',
        'fixed': '250',
        'percentage': 0,
      });

      expect(tip.isSet, isTrue);
      expect(tip.fixed!.format(), r'$2.50');
    });

    test('a type with no amount behind it is not a tip', () {
      final tip = tipFrom({
        'enabled': true,
        'allow': ['fixed'],
        'type': 'fixed',
        'fixed': '0',
        'percentage': 0,
      });

      expect(tip.isSet, isFalse);
    });
  });

  group('on the cart payload', () {
    test('the tip rides the cart, so every read refreshes it', () {
      final cart = Cart.fromJson(cartJson({
        'enabled': true,
        'allow': ['fixed', 'percentage'],
        'where': 'both',
        'heading': 'Do you want to provide a tip?',
        'type': 'percentage',
        'fixed': '0',
        'percentage': 15,
      }));

      expect(cart.tip.enabled, isTrue);
      expect(cart.tip.percentage, 15);
    });

    test('an older plugin sends none, which reads as "no tipping here"', () {
      final cart = Cart.fromJson(cartJson(null));

      expect(cart.tip.enabled, isFalse);
      expect(cart.tip.allow, isEmpty);
    });
  });
}

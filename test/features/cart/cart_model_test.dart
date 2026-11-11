import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/currency.dart';
import 'package:food_menu/src/core/store_api/models/money.dart';

import 'fake_cart_repository.dart';

void main() {
  group('a real cart payload', () {
    final cart = cartFromFixture('cart_with_addons');

    test('reads lines, units and totals', () {
      expect(cart.items, hasLength(2));
      // Three units across two lines — the count is units, not rows.
      expect(cart.itemsCount, 3);
      expect(cart.totals.totalPrice.format(), r'$23.50');
    });

    test('reads the add-ons off the plugin extension', () {
      final lemonade = cart.items.firstWhere((i) => i.name == 'Fresh Lemonade');

      expect(lemonade.addons.isNotEmpty, isTrue);
      expect(
        lemonade.addons.addons.map((a) => a.value),
        ['Medium 12"', 'Mushrooms', 'No ice please'],
      );
      expect(
        lemonade.addons.addons.map((a) => a.groupId),
        ['0', '1', '2'],
      );
    });

    test('a per-option quantity reads back with its price', () {
      final lemonade = cart.items.firstWhere((i) => i.name == 'Fresh Lemonade');
      final mushrooms =
          lemonade.addons.addons.firstWhere((a) => a.value == 'Mushrooms');

      expect(mushrooms.quantity, 2);
      expect(mushrooms.priceSingle.minorUnits, 75);
      expect(mushrooms.price.minorUnits, 150);
      expect(mushrooms.label, 'Mushrooms ×2');
    });

    test('the dish part and the add-on part sum to the unit price', () {
      // The guarantee task 4.3 built the split to keep.
      final lemonade = cart.items.firstWhere((i) => i.name == 'Fresh Lemonade');
      final addons = lemonade.addons;

      expect(
        addons.basePrice.minorUnits + addons.addonsTotalCharged.minorUnits,
        lemonade.prices.price.minorUnits,
      );
      expect(addons.basePrice.minorUnits, 325);
      expect(addons.addonsTotalCharged.minorUnits, 400);
    });

    test('a line with no add-ons reports none, not null', () {
      final margherita = cart.items.firstWhere((i) => i.name == 'Margherita');

      expect(margherita.addons.isEmpty, isTrue);
      expect(margherita.addons.summary, '');
    });

    test('the summary reads as one line under the dish name', () {
      final lemonade = cart.items.firstWhere((i) => i.name == 'Fresh Lemonade');

      expect(
        lemonade.addons.summary,
        'Medium 12" · Mushrooms ×2 · No ice please',
      );
    });
  });

  group('a store without the extension', () {
    test('an empty extensions block is no add-ons, not a parse failure', () {
      final item = CartItem.fromJson(const {
        'key': 'abc',
        'id': 1,
        'quantity': 1,
        'name': 'Garlic Bread',
        'extensions': <String, dynamic>{},
      });

      expect(item.addons.isEmpty, isTrue);
      expect(item.addons.addons, isEmpty);
    });

    test('a missing extensions key is tolerated too', () {
      final item = CartItem.fromJson(const {
        'key': 'abc',
        'id': 1,
        'quantity': 1,
        'name': 'Garlic Bread',
      });

      expect(item.addons.isEmpty, isTrue);
    });
  });

  group('null ids', () {
    test('a reworded group reads back with no ids but a real price', () {
      // What task 4.3 sends when the group can no longer be matched.
      final item = CartItem.fromJson(const {
        'key': 'abc',
        'id': 1,
        'quantity': 1,
        'name': 'Iced Latte',
        'extensions': {
          'food-menu-pro': {
            'addons': [
              {
                'group_id': null,
                'group_title': 'Make it a meal',
                'field_type': 'dropdown',
                'option_id': null,
                'value': 'Add fries & a drink',
                'quantity': 1,
                'price': '325',
                'price_single': '325',
              },
            ],
            'addons_total': '325',
            'addons_total_charged': '325',
            'base_price': '395',
            'currency_code': 'USD',
            'currency_minor_unit': 2,
            'currency_prefix': r'$',
          },
        },
      });

      final addon = item.addons.addons.single;
      expect(addon.groupId, isNull);
      expect(addon.optionId, isNull);
      expect(addon.value, 'Add fries & a drink');
      expect(addon.price.format(), r'$3.25');
    });
  });

  group('quantity limits', () {
    test('a step down below the minimum is what removes a line', () {
      const limits = QuantityLimits(
        minimum: 2,
        maximum: 10,
        multipleOf: 2,
        editable: true,
      );

      expect(limits.clamp(1), 2);
      expect(limits.clamp(3), 2);
      expect(limits.clamp(12), 10);
    });
  });

  group('currency', () {
    test('the extension carries its own, inline like the Store API', () {
      final cart = cartFromFixture('cart_with_addons');
      final lemonade = cart.items.firstWhere((i) => i.name == 'Fresh Lemonade');

      expect(lemonade.addons.currency.code, 'USD');
      expect(lemonade.addons.currency.prefix, isNotEmpty);
      expect(lemonade.addons.addons.first.price.format(), r'$2.50');
    });

    test('a block with no currency keys borrows the line totals', () {
      final item = CartItem.fromJson(const {
        'key': 'abc',
        'id': 1,
        'quantity': 1,
        'name': 'Dish',
        'totals': {'line_total': '100', 'currency_code': 'EUR'},
        'extensions': {
          'food-menu-pro': {
            'addons': [
              {'value': 'Extra', 'price': '50'},
            ],
          },
        },
      });

      expect(item.addons.currency.code, 'EUR');
    });
  });

  test('an empty cart is empty, with zero totals', () {
    final cart = Cart.empty();

    expect(cart.isEmpty, isTrue);
    expect(cart.itemsCount, 0);
    expect(cart.totals.totalPrice, Money.zero(Currency.fallback));
  });

  group('a variable line', () {
    test('carries the chosen attributes, which item_data does not', () {
      final item = CartItem.fromJson(const {
        'key': 'abc',
        'id': 28,
        'name': 'Build Your Pizza',
        'quantity': 1,
        // Empty for a variable product — the Store API puts nothing here.
        'item_data': <Object>[],
        'variation': [
          {
            'raw_attribute': 'attribute_size',
            'attribute': 'Size',
            'value': 'Small',
          },
        ],
      });

      expect(item.variation, hasLength(1));
      expect(item.variation.single.name, 'Size');
      expect(item.variation.single.value, 'Small');
    });

    test('an attribute with no value is dropped rather than drawn blank', () {
      final item = CartItem.fromJson(const {
        'key': 'abc',
        'id': 28,
        'variation': [
          {'attribute': 'Size', 'value': ''},
        ],
      });

      expect(item.variation, isEmpty);
    });

    test('a simple line has no variation at all', () {
      final item = CartItem.fromJson(const {'key': 'abc', 'id': 26});

      expect(item.variation, isEmpty);
    });
  });
}

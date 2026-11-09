import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/currency.dart';

import 'fake_addons_repository.dart';

void main() {
  group('parsing a real payload', () {
    test('reads the groups in the order the server sent them', () {
      final addons = addonsFromFixture('product_addons');

      expect(addons.productId, 25);
      expect(
        addons.groups.map((g) => g.title),
        ['Choose your size', 'Extra toppings', 'Anything else?'],
      );
      expect(
        addons.groups.map((g) => g.type),
        [AddonFieldType.radio, AddonFieldType.checkbox, AddonFieldType.textarea],
      );
    });

    test('keeps the group id as the server key, not the position', () {
      // Global add-ons keep their stored keys, so an id is not an index —
      // mixing the two is what silently dropped selections before 4.3.
      final addons = addonsFromFixture('product_addons_global');

      expect(addons.groups.map((g) => g.id), ['0', '1']);
      expect(addons.groups.first.type, AddonFieldType.dropdown);
    });

    test('prices arrive as minor units, not as a decimal', () {
      final size = addonsFromFixture('product_addons').groups.first;

      expect(size.options.map((o) => o.label),
          ['Small 9"', 'Medium 12"', 'Large 15"']);
      expect(size.options[0].price.minorUnits, 0);
      expect(size.options[1].price.minorUnits, 250);
      expect(size.options[2].price.minorUnits, 400);
      expect(size.options[1].price.format(), r'$2.50');
    });

    test('currency comes off the payload itself', () {
      final addons = addonsFromFixture('product_addons');

      expect(addons.currency.code, 'USD');
      expect(addons.currency.minorUnit, 2);
    });

    test('a quantity group and a text group are marked as such', () {
      final groups = addonsFromFixture('product_addons').groups;

      expect(groups[1].optionQuantity, isTrue);
      expect(groups[1].maxSelection, 3);
      expect(groups[2].type.isText, isTrue);
      expect(groups[2].optionQuantity, isFalse);
    });
  });

  group('groups the app cannot draw', () {
    AddonGroup? parse(Map<String, dynamic> json) =>
        AddonGroup.tryParse(json, Currency.fallback);

    test('an unknown type is dropped rather than guessed', () {
      // A type the plugin adds later must not land as a nameless control.
      expect(
        parse({
          'id': '0',
          'title': 'Cooking style',
          'type': 'colour_picker',
          'options': [
            {'id': '0', 'label': 'Rare', 'price': '0'},
          ],
        }),
        isNull,
      );
    });

    test('a group with no title is dropped', () {
      expect(
        parse({
          'id': '0',
          'title': '   ',
          'type': 'radio',
          'options': [
            {'id': '0', 'label': 'One', 'price': '0'},
          ],
        }),
        isNull,
      );
    });

    test('a choice group with no options is dropped', () {
      expect(parse({'id': '0', 'title': 'Size', 'type': 'radio'}), isNull);
    });

    test('a text group with no options is kept — its price is optional', () {
      final group = parse({'id': '0', 'title': 'Note', 'type': 'text'});

      expect(group, isNotNull);
      expect(group!.options, isEmpty);
    });

    test('an option with no label is dropped, the rest of the group stays', () {
      final group = parse({
        'id': '0',
        'title': 'Sauce',
        'type': 'checkbox',
        'options': [
          {'id': '0', 'label': 'Garlic', 'price': '50'},
          {'id': '1', 'label': '', 'price': '50'},
        ],
      });

      expect(group!.options.map((o) => o.label), ['Garlic']);
    });
  });

  group('limits', () {
    AddonGroup group({
      String type = 'checkbox',
      bool required = false,
      int min = 0,
      int max = 0,
    }) {
      return AddonGroup.tryParse({
        'id': '0',
        'title': 'Toppings',
        'type': type,
        'required': required,
        'min_selection': min,
        'max_selection': max,
        'options': [
          {'id': '0', 'label': 'A', 'price': '0'},
          {'id': '1', 'label': 'B', 'price': '0'},
        ],
      }, Currency.fallback)!;
    }

    test('zero means no limit on both ends', () {
      expect(group().choiceLimit, isNull);
      expect(group().choiceFloor, 0);
    });

    test('a single choice is capped at one whatever the data says', () {
      expect(group(type: 'radio', max: 5).choiceLimit, 1);
      expect(group(type: 'dropdown', max: 0).choiceLimit, 1);
    });

    test('required and min_selection can disagree, and the stricter wins', () {
      expect(group(required: true).choiceFloor, 1);
      expect(group(min: 2).choiceFloor, 2);
      expect(group(required: true, min: 3).choiceFloor, 3);
    });

    test('a required text group needs one answer', () {
      expect(group(type: 'text', required: true).choiceFloor, 1);
      expect(group(type: 'text').choiceFloor, 0);
    });
  });
}

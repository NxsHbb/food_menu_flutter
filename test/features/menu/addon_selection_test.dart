import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/currency.dart';
import 'package:food_menu/src/features/menu/domain/addon_selection.dart';

import 'fake_addons_repository.dart';

void main() {
  final addons = addonsFromFixture('product_addons');
  final size = addons.groups[0]; // radio, required
  final toppings = addons.groups[1]; // checkbox, max 3, per-option quantity
  final note = addons.groups[2]; // textarea, optional

  AddonGroup parseGroup(Map<String, dynamic> json) =>
      AddonGroup.tryParse(json, Currency.fallback)!;

  group('single choice', () {
    test('a second tap replaces the first', () {
      var selection = const AddonSelection()
          .toggle(size, size.options[1])
          .toggle(size, size.options[2]);

      expect(selection.choiceFor(size).optionIds, [size.options[2].id]);
    });

    test('tapping the chosen option keeps it when the group is required', () {
      // Clearing it would only put the dish back behind a validation error.
      final selection =
          const AddonSelection().toggle(size, size.options[1]);

      expect(
        selection.toggle(size, size.options[1]).choiceFor(size).optionIds,
        [size.options[1].id],
      );
    });

    test('an optional single choice can be cleared again', () {
      final optional = parseGroup({
        'id': '9',
        'title': 'Cutlery',
        'type': 'radio',
        'options': [
          {'id': '0', 'label': 'Yes', 'price': '0'},
        ],
      });

      final selection =
          const AddonSelection().toggle(optional, optional.options[0]);

      expect(selection.choiceFor(optional).optionIds, isNotEmpty);
      expect(
        selection.toggle(optional, optional.options[0]).choices,
        isEmpty,
      );
    });
  });

  group('multiple choice', () {
    test('ticks accumulate and untick again', () {
      var selection = const AddonSelection()
          .toggle(toppings, toppings.options[0])
          .toggle(toppings, toppings.options[1]);

      expect(selection.choiceFor(toppings).optionIds, hasLength(2));

      selection = selection.toggle(toppings, toppings.options[0]);
      expect(
        selection.choiceFor(toppings).optionIds,
        [toppings.options[1].id],
      );
    });

    test('a tick past max_selection is refused, not silently dropped', () {
      final capped = parseGroup({
        'id': '1',
        'title': 'Sauces',
        'type': 'checkbox',
        'max_selection': 2,
        'options': [
          {'id': '0', 'label': 'A', 'price': '0'},
          {'id': '1', 'label': 'B', 'price': '0'},
          {'id': '2', 'label': 'C', 'price': '0'},
        ],
      });

      var selection = const AddonSelection()
          .toggle(capped, capped.options[0])
          .toggle(capped, capped.options[1]);

      expect(selection.limitReached(capped), isTrue);

      final refused = selection.toggle(capped, capped.options[2]);
      expect(refused, same(selection));
    });

    test('max_selection of zero means no limit', () {
      final open = parseGroup({
        'id': '1',
        'title': 'Extras',
        'type': 'checkbox',
        'max_selection': 0,
        'options': [
          {'id': '0', 'label': 'A', 'price': '0'},
          {'id': '1', 'label': 'B', 'price': '0'},
        ],
      });

      final selection = const AddonSelection()
          .toggle(open, open.options[0])
          .toggle(open, open.options[1]);

      expect(selection.limitReached(open), isFalse);
      expect(selection.choiceFor(open).optionIds, hasLength(2));
    });
  });

  group('per-option quantity', () {
    test('defaults to one and clamps at the plugin ceiling', () {
      final option = toppings.options[0];
      var selection = const AddonSelection().toggle(toppings, option);

      expect(selection.quantityOf(toppings, option), 1);

      selection = selection.setQuantity(toppings, option, 4);
      expect(selection.quantityOf(toppings, option), 4);

      // `AddonFields` clamps to 10 server-side, so promising 25 here would
      // preview a total the cart will not charge.
      selection = selection.setQuantity(toppings, option, 25);
      expect(selection.quantityOf(toppings, option), 10);
    });

    test('dropping to zero unticks the option', () {
      final option = toppings.options[0];
      final selection = const AddonSelection()
          .toggle(toppings, option)
          .setQuantity(toppings, option, 0);

      expect(selection.isSelected(toppings, option), isFalse);
    });

    test('a quantity on an unselected option is ignored', () {
      final selection = const AddonSelection()
          .setQuantity(toppings, toppings.options[0], 3);

      expect(selection.choices, isEmpty);
    });
  });

  group('text groups', () {
    test('text is kept, and trimmed to the character limit', () {
      final limited = parseGroup({
        'id': '0',
        'title': 'Message',
        'type': 'text',
        'char_limit': 5,
      });

      final selection =
          const AddonSelection().setText(limited, 'Happy birthday');

      expect(selection.choiceFor(limited).text, 'Happy');
    });

    test('whitespace alone does not count as an answer', () {
      final required = parseGroup({
        'id': '0',
        'title': 'Message',
        'type': 'text',
        'required': true,
      });

      final selection = const AddonSelection().setText(required, '   ');

      expect(selection.unanswered([required]), [required]);
    });
  });

  group('defaults', () {
    test('an option marked default starts ticked', () {
      final withDefault = parseGroup({
        'id': '0',
        'title': 'Cutlery',
        'type': 'radio',
        'options': [
          {'id': '0', 'label': 'Include', 'price': '0'},
          {'id': '1', 'label': 'No thanks', 'price': '0', 'is_default': true},
        ],
      });

      final selection = AddonSelection.fromDefaults([withDefault]);

      expect(selection.choiceFor(withDefault).optionIds, ['1']);
      expect(selection.isSatisfied([withDefault]), isTrue);
    });

    test('a single-choice group takes only the first default', () {
      final messy = parseGroup({
        'id': '0',
        'title': 'Size',
        'type': 'radio',
        'options': [
          {'id': '0', 'label': 'S', 'price': '0', 'is_default': true},
          {'id': '1', 'label': 'M', 'price': '0', 'is_default': true},
        ],
      });

      expect(AddonSelection.fromDefaults([messy]).choiceFor(messy).optionIds,
          ['0']);
    });

    test('defaults never exceed a checkbox maximum', () {
      final capped = parseGroup({
        'id': '0',
        'title': 'Extras',
        'type': 'checkbox',
        'max_selection': 1,
        'options': [
          {'id': '0', 'label': 'A', 'price': '0', 'is_default': true},
          {'id': '1', 'label': 'B', 'price': '0', 'is_default': true},
        ],
      });

      expect(
        AddonSelection.fromDefaults([capped]).choiceFor(capped).optionIds,
        hasLength(1),
      );
    });
  });

  group('what is still unanswered', () {
    test('a required group with nothing chosen is listed, in group order', () {
      final selection = const AddonSelection();

      expect(selection.unanswered(addons.groups), [size]);
      expect(selection.isSatisfied(addons.groups), isFalse);
    });

    test('answering it satisfies the dish', () {
      final selection =
          const AddonSelection().toggle(size, size.options[0]);

      expect(selection.unanswered(addons.groups), isEmpty);
      expect(selection.isSatisfied(addons.groups), isTrue);
    });

    test('a min_selection short of its floor is still unanswered', () {
      final pickTwo = parseGroup({
        'id': '0',
        'title': 'Sides',
        'type': 'checkbox',
        'min_selection': 2,
        'options': [
          {'id': '0', 'label': 'A', 'price': '0'},
          {'id': '1', 'label': 'B', 'price': '0'},
        ],
      });

      final one = const AddonSelection().toggle(pickTwo, pickTwo.options[0]);
      expect(one.unanswered([pickTwo]), [pickTwo]);

      final two = one.toggle(pickTwo, pickTwo.options[1]);
      expect(two.unanswered([pickTwo]), isEmpty);
    });
  });

  group('price preview', () {
    final currency = addons.currency;

    test('adds the chosen options to nothing when nothing is chosen', () {
      expect(
        const AddonSelection().priceDelta(addons.groups, currency).minorUnits,
        0,
      );
    });

    test('sums across groups, multiplying by each option quantity', () {
      // Medium 12" is 250, Mushrooms are 75 each.
      final selection = const AddonSelection()
          .toggle(size, size.options[1])
          .toggle(toppings, toppings.options[0])
          .setQuantity(toppings, toppings.options[0], 2);

      expect(
        selection.priceDelta(addons.groups, currency).minorUnits,
        250 + 150,
      );
    });

    test('a text answer picks up the price on the first option', () {
      // Which is where the plugin's own text handler keeps it.
      final priced = parseGroup({
        'id': '0',
        'title': 'Gift message',
        'type': 'text',
        'options': [
          {'id': '0', 'label': 'Message', 'price': '199'},
        ],
      });

      expect(
        const AddonSelection()
            .setText(priced, 'Happy birthday')
            .priceDelta([priced], currency)
            .minorUnits,
        199,
      );
      expect(
        const AddonSelection().priceDelta([priced], currency).minorUnits,
        0,
      );
    });
  });

  group('the add-to-cart payload', () {
    test('sends ids, quantities only where they apply, and skips empties', () {
      final selection = const AddonSelection()
          .toggle(size, size.options[1])
          .toggle(toppings, toppings.options[0])
          .setQuantity(toppings, toppings.options[0], 2)
          .setText(note, 'No ice please');

      expect(selection.toPayload(addons.groups), [
        {'group_id': '0', 'option_ids': ['1']},
        {
          'group_id': '1',
          'option_ids': ['0'],
          'quantities': {'0': 2},
        },
        {'group_id': '2', 'text': 'No ice please'},
      ]);
    });

    test('a quantity of one is left out', () {
      final selection =
          const AddonSelection().toggle(toppings, toppings.options[0]);

      expect(selection.toPayload([toppings]), [
        {'group_id': '1', 'option_ids': ['0']},
      ]);
    });

    test('untouched groups are absent, not sent empty', () {
      expect(const AddonSelection().toPayload(addons.groups), isEmpty);
    });

    test('text is trimmed before it is sent', () {
      final selection =
          const AddonSelection().setText(note, '  no ice  ');

      expect(selection.toPayload([note]), [
        {'group_id': '2', 'text': 'no ice'},
      ]);
    });
  });
}

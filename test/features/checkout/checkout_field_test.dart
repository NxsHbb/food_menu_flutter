import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/checkout/domain/checkout_field.dart';

CheckoutField _text({bool required = false, String key = 'custom_0'}) {
  return CheckoutField.fromJson({
    'key': key,
    'label': 'Apartment / buzzer',
    'type': 'text',
    'required': required,
    'multiple': false,
    'options': const <String>[],
  });
}

CheckoutField _select({bool multiple = false, bool required = false}) {
  return CheckoutField.fromJson({
    'key': 'custom_1',
    'label': 'Allergies',
    'type': 'select',
    'required': required,
    'multiple': multiple,
    'options': const ['Nuts', 'Dairy', 'Gluten'],
  });
}

void main() {
  group('CheckoutField', () {
    test('reads a definition as the server shapes it', () {
      final field = _select(multiple: true, required: true);

      expect(field.key, 'custom_1');
      expect(field.type, CheckoutFieldType.select);
      expect(field.required, isTrue);
      expect(field.multiple, isTrue);
      expect(field.options, ['Nuts', 'Dairy', 'Gluten']);
    });

    test('an unknown type falls back to text rather than vanishing', () {
      final field = CheckoutField.fromJson(const {
        'key': 'custom_0',
        'label': 'Something new',
        'type': 'colour_picker',
      });

      expect(field.type, CheckoutFieldType.text);
      expect(field.isUsable, isTrue);
    });

    test('a field with no key, no label or no options is unusable', () {
      expect(_text(key: '').isUsable, isFalse);
      expect(
        CheckoutField.fromJson(const {'key': 'custom_0', 'label': ''}).isUsable,
        isFalse,
      );
      // A select with nothing to select would strand a customer on a required
      // question they cannot answer.
      expect(
        CheckoutField.fromJson(const {
          'key': 'custom_0',
          'label': 'Pick one',
          'type': 'select',
          'options': <String>[],
        }).isUsable,
        isFalse,
      );
    });
  });

  group('answering', () {
    test('a text answer is kept, and clearing it unanswers the field', () {
      final field = _text();
      var answers = const CheckoutFieldAnswers().setText(field, 'Flat 3B');

      expect(answers.textFor(field), 'Flat 3B');

      // Blank is unanswered, not answered empty — the plugin stores only
      // non-empty values and a blank would write meta the slips then print.
      answers = answers.setText(field, '   ');
      expect(answers.forField(field), isEmpty);
    });

    test('a single-choice select replaces', () {
      final field = _select();
      final answers = const CheckoutFieldAnswers()
          .toggle(field, 'Nuts')
          .toggle(field, 'Dairy');

      expect(answers.forField(field), ['Dairy']);
    });

    test('tapping the chosen option again clears a single-choice select', () {
      final field = _select();
      final answers =
          const CheckoutFieldAnswers().toggle(field, 'Nuts').toggle(field, 'Nuts');

      // The only way to unanswer an optional select.
      expect(answers.forField(field), isEmpty);
    });

    test('a multi-select adds, removes and keeps the store own order', () {
      final field = _select(multiple: true);
      var answers = const CheckoutFieldAnswers()
          .toggle(field, 'Gluten')
          .toggle(field, 'Nuts');

      // Tapped Gluten first, but the answer reads the way the question does.
      expect(answers.forField(field), ['Nuts', 'Gluten']);

      answers = answers.toggle(field, 'Nuts');
      expect(answers.forField(field), ['Gluten']);

      answers = answers.toggle(field, 'Gluten');
      expect(answers.forField(field), isEmpty);
    });
  });

  group('required', () {
    test('names only the required questions left unanswered', () {
      final required = _text(required: true);
      final optional = _select();

      final empty = const CheckoutFieldAnswers();
      expect(empty.unanswered([required, optional]), [required]);

      final answered = empty.setText(required, 'Flat 3B');
      expect(answered.unanswered([required, optional]), isEmpty);
    });
  });

  group('the payload', () {
    test('keys by position and splits list from string', () {
      final text = _text();
      final multi = _select(multiple: true);

      final answers = const CheckoutFieldAnswers()
          .setText(text, 'Flat 3B')
          .toggle(multi, 'Nuts')
          .toggle(multi, 'Gluten');

      // A multi-select posts a list and everything else a single string,
      // which is the shape the website posts and the plugin sanitises.
      expect(answers.toPayload([text, multi]), {
        'custom_0': 'Flat 3B',
        'custom_1': ['Nuts', 'Gluten'],
      });
    });

    test('a single-choice select posts a string, not a list of one', () {
      final one = _select();
      final answers = const CheckoutFieldAnswers().toggle(one, 'Dairy');

      expect(answers.toPayload([one]), {'custom_1': 'Dairy'});
    });

    test('an unanswered field is left out entirely', () {
      final text = _text();
      final select = _select();

      expect(const CheckoutFieldAnswers().toPayload([text, select]), isEmpty);
    });

    test('an answer to a field the store has removed is not posted', () {
      final removed = _text();
      final answers = const CheckoutFieldAnswers().setText(removed, 'stale');

      // Driven by the definitions, not by what happens to be in the map, so a
      // field deleted in settings cannot resurface on an order.
      expect(answers.toPayload(const []), isEmpty);
    });
  });
}

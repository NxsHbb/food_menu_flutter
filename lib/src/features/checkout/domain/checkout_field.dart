/// One of the store's own checkout questions — `GET fmp/v1/app/checkout-fields`.
///
/// A store defines these on its settings screen: "Apartment / buzzer",
/// "Allergies". They are saved to the order and printed on the slips, and
/// until task 8.2 the app dropped every one of them — it sent
/// `fmp_custom_fields: {}` on every order, required fields included.
///
/// **The key is the field's position**, which is the website's own convention:
/// the admin order screen and the kitchen slips pair `custom_{index}` with the
/// definition at that index. The server publishes it so the app never derives
/// it; reordering the fields in settings re-keys the answers, on the website
/// just as here.
class CheckoutField {
  const CheckoutField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.multiple,
    required this.options,
  });

  factory CheckoutField.fromJson(Map<String, dynamic> json) {
    final options = json['options'];

    return CheckoutField(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: CheckoutFieldType.from(json['type'] as String? ?? ''),
      required: json['required'] == true,
      multiple: json['multiple'] == true,
      options: options is List
          ? options.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }

  /// What the answer is posted under, e.g. `custom_0`.
  final String key;

  /// The store's own wording for the question.
  final String label;

  final CheckoutFieldType type;
  final bool required;

  /// Only ever true for a select, which the server already guarantees.
  final bool multiple;

  final List<String> options;

  /// A field with no key or label cannot be drawn or posted. The server drops
  /// these already; this is the client's own guard against an older one.
  bool get isUsable =>
      key.isNotEmpty &&
      label.isNotEmpty &&
      (type == CheckoutFieldType.text || options.isNotEmpty);
}

/// The two controls a store can ask for.
enum CheckoutFieldType {
  text,
  select;

  static CheckoutFieldType from(String value) =>
      value == 'select' ? CheckoutFieldType.select : CheckoutFieldType.text;
}

/// What the customer has answered, keyed by [CheckoutField.key].
///
/// A text field holds one string; a select holds the chosen options, which is
/// a list of one unless the field is [CheckoutField.multiple].
class CheckoutFieldAnswers {
  const CheckoutFieldAnswers([this.values = const {}]);

  final Map<String, List<String>> values;

  List<String> forField(CheckoutField field) => values[field.key] ?? const [];

  String textFor(CheckoutField field) {
    final answer = forField(field);
    return answer.isEmpty ? '' : answer.first;
  }

  bool isSelected(CheckoutField field, String option) =>
      forField(field).contains(option);

  /// Replaces a text field's answer. An empty string clears it, so a field
  /// typed into and then emptied is unanswered rather than answered blank.
  CheckoutFieldAnswers setText(CheckoutField field, String text) {
    final next = Map<String, List<String>>.from(values);

    if (text.trim().isEmpty) {
      next.remove(field.key);
    } else {
      next[field.key] = [text];
    }

    return CheckoutFieldAnswers(next);
  }

  /// Toggles one option of a select.
  ///
  /// A single-choice select **replaces**; a multiple one adds and removes, and
  /// clearing the last option leaves the field unanswered rather than holding
  /// an empty list.
  CheckoutFieldAnswers toggle(CheckoutField field, String option) {
    final next = Map<String, List<String>>.from(values);
    final current = next[field.key] ?? const <String>[];

    if (!field.multiple) {
      // Tapping the chosen one again clears it, which is the only way to
      // unanswer an optional select.
      if (current.contains(option)) {
        next.remove(field.key);
      } else {
        next[field.key] = [option];
      }
      return CheckoutFieldAnswers(next);
    }

    final chosen = current.contains(option)
        ? (current.where((o) => o != option).toList(growable: false))
        : [...current, option];

    if (chosen.isEmpty) {
      next.remove(field.key);
    } else {
      // Kept in the store's own order, not tap order, so the answer reads the
      // way the question does.
      next[field.key] = [
        for (final o in field.options)
          if (chosen.contains(o)) o,
      ];
    }

    return CheckoutFieldAnswers(next);
  }

  /// The required fields still unanswered, in the order they are drawn.
  List<CheckoutField> unanswered(List<CheckoutField> fields) {
    return [
      for (final field in fields)
        if (field.required && forField(field).isEmpty) field,
    ];
  }

  /// What the `food-menu-pro` checkout extension takes under
  /// `fmp_custom_fields`.
  ///
  /// A multi-select posts a list and everything else a single string, which is
  /// the shape the plugin sanitises and the shape the website posts. An
  /// unanswered field is **left out entirely** rather than sent empty: the
  /// plugin stores only non-empty answers, and sending blanks would write
  /// empty meta the slips would then print.
  Map<String, Object> toPayload(List<CheckoutField> fields) {
    final out = <String, Object>{};

    for (final field in fields) {
      final answer = forField(field);
      if (answer.isEmpty) continue;

      out[field.key] = field.multiple ? answer : answer.first;
    }

    return out;
  }
}

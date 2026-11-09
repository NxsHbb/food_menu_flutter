import '../../../core/store_api/models/currency.dart';
import '../../../core/store_api/models/money.dart';
import 'product_addons.dart';

/// What the customer has chosen on one dish, and the rules that apply to it.
///
/// Immutable: every change returns a new selection, so the detail screen holds
/// one value and rebuilds from it.
///
/// **The server is still the authority.** It validates every rule again and
/// prices the line itself, and `AppCartAddons` refuses anything that does not
/// hold. What this does is keep the customer from being told "no" after the
/// fact: it enforces the same limits while they tap, and it adds up a
/// [priceDelta] for the preview on the add button. See `CONTEXT.md` on why
/// that preview is not a substitute for the cart's own total.
class AddonSelection {
  const AddonSelection({this.choices = const {}});

  /// Everything the dish's own defaults ask for, pre-ticked.
  ///
  /// `is_default` is the admin screen's answer to "what should already be
  /// selected", and ignoring it would make a required group look unanswered
  /// when the store had in fact answered it.
  factory AddonSelection.fromDefaults(List<AddonGroup> groups) {
    final choices = <String, GroupChoice>{};

    for (final group in groups) {
      if (group.type.isText) continue;

      final defaults = group.options.where((o) => o.isDefault).toList();
      if (defaults.isEmpty) continue;

      // A single-choice group can only hold one, whatever the data says.
      final chosen = group.type.isSingleChoice ? [defaults.first] : defaults;
      final limit = group.choiceLimit;
      final capped = limit == null || chosen.length <= limit
          ? chosen
          : chosen.take(limit).toList();

      choices[group.id] = GroupChoice(
        optionIds: capped.map((o) => o.id).toList(growable: false),
      );
    }

    return AddonSelection(choices: choices);
  }

  /// Keyed by [AddonGroup.id]. A group the customer has not touched is absent
  /// rather than present-and-empty.
  final Map<String, GroupChoice> choices;

  GroupChoice choiceFor(AddonGroup group) =>
      choices[group.id] ?? const GroupChoice();

  bool isSelected(AddonGroup group, AddonOption option) =>
      choiceFor(group).optionIds.contains(option.id);

  /// How many of [option] are chosen, which is 1 for a group without its own
  /// quantity stepper.
  int quantityOf(AddonGroup group, AddonOption option) {
    final choice = choiceFor(group);
    if (!choice.optionIds.contains(option.id)) return 0;
    return choice.quantities[option.id] ?? 1;
  }

  /// Ticks or unticks an option, obeying the group's own kind and limits.
  ///
  /// Returns the same instance when the tap would break a rule — a single
  /// choice is replaced, but a checkbox already at its maximum is refused, and
  /// [limitReached] says which so the screen can explain it rather than
  /// swallowing the tap.
  AddonSelection toggle(AddonGroup group, AddonOption option) {
    final current = choiceFor(group);

    if (group.type.isSingleChoice) {
      // Tapping the chosen option again keeps it when the group is required:
      // emptying it would only put the dish back behind a validation error.
      if (current.optionIds.contains(option.id)) {
        if (group.choiceFloor > 0) return this;
        return _withChoice(group.id, const GroupChoice());
      }
      return _withChoice(group.id, GroupChoice(optionIds: [option.id]));
    }

    if (current.optionIds.contains(option.id)) {
      final ids = current.optionIds.where((id) => id != option.id).toList();
      final quantities = Map<String, int>.from(current.quantities)
        ..remove(option.id);
      return _withChoice(
        group.id,
        GroupChoice(optionIds: ids, quantities: quantities),
      );
    }

    final limit = group.choiceLimit;
    if (limit != null && current.optionIds.length >= limit) return this;

    return _withChoice(
      group.id,
      current.copyWith(optionIds: [...current.optionIds, option.id]),
    );
  }

  /// Whether another tick on [group] would be refused.
  bool limitReached(AddonGroup group) {
    final limit = group.choiceLimit;
    if (limit == null || group.type.isSingleChoice) return false;
    return choiceFor(group).optionIds.length >= limit;
  }

  /// Sets how many of one option, within the range the server accepts.
  ///
  /// Dropping to zero unticks it, which is what the stepper's minus does on
  /// its last step.
  AddonSelection setQuantity(AddonGroup group, AddonOption option, int qty) {
    final current = choiceFor(group);
    if (!current.optionIds.contains(option.id)) return this;
    if (qty <= 0) return toggle(group, option);

    final clamped = qty > maxOptionQuantity ? maxOptionQuantity : qty;

    return _withChoice(
      group.id,
      current.copyWith(
        quantities: {...current.quantities, option.id: clamped},
      ),
    );
  }

  /// Stores what the customer typed into a `text` or `textarea` group.
  AddonSelection setText(AddonGroup group, String text) {
    final trimmed = text.trimLeft();
    final capped = group.charLimit > 0 && trimmed.length > group.charLimit
        ? trimmed.substring(0, group.charLimit)
        : trimmed;

    return _withChoice(group.id, choiceFor(group).copyWith(text: capped));
  }

  /// The groups still standing between the customer and the add button.
  ///
  /// In the order the groups were given, so the add button can name the first
  /// one and the screen can scroll to it.
  List<AddonGroup> unanswered(List<AddonGroup> groups) {
    return groups.where((group) {
      final floor = group.choiceFloor;
      if (floor == 0) return false;
      if (group.type.isText) return choiceFor(group).text.trim().isEmpty;
      return choiceFor(group).optionIds.length < floor;
    }).toList(growable: false);
  }

  bool isSatisfied(List<AddonGroup> groups) => unanswered(groups).isEmpty;

  /// What the current choices add to the dish's own price.
  ///
  /// A preview, not a quote. The plugin can discount a line server-side, and
  /// the cart response is the only place the charged amount comes from.
  Money priceDelta(List<AddonGroup> groups, Currency currency) {
    var total = Money.zero(currency);

    for (final group in groups) {
      final choice = choiceFor(group);

      if (group.type.isText) {
        // A text add-on keeps its price on the first option, which is where
        // the plugin's own `get_text_options_data()` looks for it.
        if (choice.text.trim().isEmpty) continue;
        final option = group.options.firstOrNull;
        if (option != null) total += option.price;
        continue;
      }

      for (final id in choice.optionIds) {
        final option = group.optionById(id);
        if (option == null) continue;
        total += option.price * (choice.quantities[id] ?? 1);
      }
    }

    return total;
  }

  /// The `extensions['food-menu-pro']['addons']` body for `cart/add-item`.
  ///
  /// Ids, never labels: a label is display copy that changes whenever the
  /// restaurant rewords a topping, and the plugin matches on the ids this
  /// sends. Groups with nothing chosen are left out entirely.
  List<Map<String, Object>> toPayload(List<AddonGroup> groups) {
    final out = <Map<String, Object>>[];

    for (final group in groups) {
      final choice = choiceFor(group);

      if (group.type.isText) {
        final text = choice.text.trim();
        if (text.isEmpty) continue;
        out.add({'group_id': group.id, 'text': text});
        continue;
      }

      if (choice.optionIds.isEmpty) continue;

      final entry = <String, Object>{
        'group_id': group.id,
        'option_ids': choice.optionIds,
      };

      // Only sent where the group actually offers a stepper, and only for the
      // options that moved off one.
      if (group.optionQuantity) {
        final quantities = <String, int>{};
        for (final id in choice.optionIds) {
          final qty = choice.quantities[id] ?? 1;
          if (qty > 1) quantities[id] = qty;
        }
        if (quantities.isNotEmpty) entry['quantities'] = quantities;
      }

      out.add(entry);
    }

    return out;
  }

  AddonSelection _withChoice(String groupId, GroupChoice choice) {
    final next = Map<String, GroupChoice>.from(choices);

    if (choice.isEmpty) {
      next.remove(groupId);
    } else {
      next[groupId] = choice;
    }

    return AddonSelection(choices: next);
  }

  /// The ceiling the plugin's own `AddonFields` clamps a per-option quantity
  /// to. Mirrored here so the preview cannot promise a total the cart will
  /// not charge.
  static const maxOptionQuantity = 10;
}

/// One group's answer.
class GroupChoice {
  const GroupChoice({
    this.optionIds = const [],
    this.quantities = const {},
    this.text = '',
  });

  /// Chosen option ids, in the order they were tapped.
  final List<String> optionIds;

  /// How many of each chosen option, for groups with a stepper. An option
  /// absent from here is one of it.
  final Map<String, int> quantities;

  /// What was typed, for `text` and `textarea` groups.
  final String text;

  bool get isEmpty => optionIds.isEmpty && text.isEmpty;

  GroupChoice copyWith({
    List<String>? optionIds,
    Map<String, int>? quantities,
    String? text,
  }) {
    return GroupChoice(
      optionIds: optionIds ?? this.optionIds,
      quantities: quantities ?? this.quantities,
      text: text ?? this.text,
    );
  }
}

import '../../../core/store_api/models/currency.dart';
import '../../../core/store_api/models/money.dart';

/// The add-on controls a dish offers, as `GET fmp/v1/app/products/{id}/addons`
/// describes them.
///
/// Add-ons are the one part of a dish the Store API knows nothing about — they
/// live in plugin meta and the website renders them with its own PHP — so this
/// is a separate call, and the only one in `fmp/v1/app/*` that needs no token.
/// See `CONTEXT.md`.
///
/// Nothing here is derived locally that the server already decided: the
/// product/global choice, the "Free" badge and the price of a non-numeric
/// entry are all settled server-side.
class ProductAddons {
  const ProductAddons({
    required this.productId,
    required this.currency,
    required this.groups,
  });

  /// A dish with no add-ons at all, which is the common case.
  const ProductAddons.none(this.productId)
      : currency = Currency.fallback,
        groups = const [];

  factory ProductAddons.fromJson(Map<String, dynamic> json) {
    // This endpoint nests the currency keys under `currency`, while the
    // Store API repeats them inline on every price block. Both shapes are
    // read, because the same model has to cope with a cart item's
    // `extensions['food-menu-pro']`, where they are flat.
    final block = json['currency'];
    final currency = Currency.fromJson(
      block is Map ? block.cast<String, dynamic>() : json,
    );
    final raw = json['groups'];

    return ProductAddons(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      currency: currency,
      groups: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => AddonGroup.tryParse(e.cast<String, dynamic>(), currency))
              .nonNulls
              .toList(growable: false)
          : const [],
    );
  }

  final int productId;

  /// How to render the option prices. Comes back in the Store API's own
  /// `currency_*` keys, so [Currency.fromJson] reads it unchanged.
  final Currency currency;

  /// Groups in the order the server sent them, which is its `position` order.
  /// Render them as given.
  final List<AddonGroup> groups;

  bool get isEmpty => groups.isEmpty;
  bool get isNotEmpty => groups.isNotEmpty;
}

/// The field types the plugin can render, and so the only ones that arrive.
enum AddonFieldType {
  dropdown,
  checkbox,
  radio,
  text,
  textarea;

  static AddonFieldType? tryParse(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  /// One choice out of several. A dropdown is drawn as a list like a radio
  /// group rather than as a picker: the design has no dropdown anywhere, and
  /// on a phone a list of three toppings beats a menu that hides two of them.
  bool get isSingleChoice => this == radio || this == dropdown;

  bool get isMultiChoice => this == checkbox;

  /// Free text, which has no options to choose between.
  bool get isText => this == text || this == textarea;
}

/// One add-on group: a question about a dish, and the answers allowed.
class AddonGroup {
  const AddonGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.required,
    required this.position,
    required this.minSelection,
    required this.maxSelection,
    required this.optionQuantity,
    required this.placeholder,
    required this.charLimit,
    required this.freeLabel,
    required this.options,
  });

  /// Returns null for a group the app cannot draw, rather than guessing one.
  ///
  /// The server already drops groups with no title or an unknown type, so this
  /// only bites on a plugin newer than the app — a type added later arrives as
  /// a word this build has never heard of, and a silently skipped group beats
  /// a nameless control on the dish screen.
  static AddonGroup? tryParse(Map<String, dynamic> json, Currency currency) {
    final type = AddonFieldType.tryParse(json['type'] as String?);
    final title = (json['title'] as String? ?? '').trim();

    if (type == null || title.isEmpty) return null;

    final raw = json['options'];
    final options = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => AddonOption.fromJson(e.cast<String, dynamic>(), currency))
            .where((o) => o.label.isNotEmpty)
            .toList(growable: false)
        : const <AddonOption>[];

    // A choice group with nothing to choose from is not a question.
    if (!type.isText && options.isEmpty) return null;

    return AddonGroup(
      id: '${json['id'] ?? ''}',
      title: title,
      description: json['description'] as String? ?? '',
      type: type,
      required: json['required'] as bool? ?? false,
      position: (json['position'] as num?)?.toInt() ?? 0,
      minSelection: (json['min_selection'] as num?)?.toInt() ?? 0,
      maxSelection: (json['max_selection'] as num?)?.toInt() ?? 0,
      optionQuantity: json['option_quantity'] as bool? ?? false,
      placeholder: json['placeholder'] as String? ?? '',
      charLimit: (json['char_limit'] as num?)?.toInt() ?? 0,
      freeLabel: json['free_label'] as bool? ?? false,
      options: options,
    );
  }

  /// The group's id, and what goes back in `group_id`.
  ///
  /// A string because it is the plugin's own key, not an index — see
  /// `FINDINGS.md` on why the two are not the same thing.
  final String id;

  final String title;
  final String description;
  final AddonFieldType type;

  /// Whether an answer is needed before the dish can be added.
  final bool required;

  /// The server's ordering, kept so it survives anything that re-sorts.
  final int position;

  /// **Zero means no limit** on both of these, which is how the admin screen
  /// and the website read them.
  final int minSelection;
  final int maxSelection;

  /// Whether each option carries its own quantity stepper.
  final bool optionQuantity;

  /// For [AddonFieldType.text] and [AddonFieldType.textarea].
  final String placeholder;
  final int charLimit;

  /// Whether zero-priced options show a "Free" badge. **Already resolved by
  /// the server** from a global setting the app cannot see — do not re-derive.
  final bool freeLabel;

  final List<AddonOption> options;

  /// How many options may be chosen, or null for no limit.
  ///
  /// A single-choice group is capped at one whatever the stored numbers say,
  /// because the server refuses a second selection on one.
  int? get choiceLimit {
    if (type.isSingleChoice) return 1;
    return maxSelection > 0 ? maxSelection : null;
  }

  /// How many options must be chosen for the group to be satisfied.
  ///
  /// `required` and a `min_selection` can both be set, and they can disagree;
  /// the server treats either as reason enough, so the stricter wins.
  int get choiceFloor {
    if (type.isText) return required ? 1 : 0;
    final floor = minSelection > 0 ? minSelection : 0;
    if (required && floor < 1) return 1;
    return floor;
  }

  AddonOption? optionById(String id) =>
      options.where((o) => o.id == id).firstOrNull;
}

/// One answer within a group.
class AddonOption {
  const AddonOption({
    required this.id,
    required this.label,
    required this.description,
    required this.image,
    required this.price,
    required this.priceType,
    required this.isDefault,
  });

  factory AddonOption.fromJson(Map<String, dynamic> json, Currency currency) {
    return AddonOption(
      id: '${json['id'] ?? ''}',
      label: (json['label'] as String? ?? '').trim(),
      description: json['description'] as String? ?? '',
      image: json['image'] as String? ?? '',
      // Minor-unit strings with the Store API's own currency keys, so the
      // app's one money parser reads them. Never a second way to parse a price.
      price: Money.parseOrZero(json['price'], currency),
      priceType: json['price_type'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  /// The option's id, and what goes back in `option_ids`.
  final String id;

  final String label;
  final String description;

  /// Option thumbnail URL, empty when there is none. Not drawn yet — see
  /// `PROGRESS.md` for task 4.4.
  final String image;

  /// What choosing this adds to the dish. Zero for a free choice.
  final Money price;

  final String priceType;

  /// Whether the admin screen marked this as pre-selected.
  final bool isDefault;

  bool get isFree => price.isZero;
}

/// How to draw one input of the address form, as the server describes it.
///
/// Everything here comes from `GET fmp/v1/app/address-fields`, which is
/// WooCommerce's own answer for the chosen country. **None of it is
/// hard-coded in the app**: the US wants a required `State` and a `ZIP Code`,
/// Bangladesh a required `District` and an optional `Postcode / ZIP`, the UK
/// no state list at all. See `FINDINGS.md`.
class AddressField {
  const AddressField({
    required this.key,
    required this.label,
    required this.required,
    required this.priority,
    required this.type,
    this.options = const {},
  });

  factory AddressField.fromJson(Map<String, dynamic> json) {
    final options = json['options'];

    return AddressField(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'text',
      options: options is Map
          ? {
              for (final entry in options.entries)
                '${entry.key}': '${entry.value}',
            }
          : const {},
    );
  }

  /// The API's field name, e.g. `address_1`.
  final String key;

  /// WooCommerce's own wording, in the store's language. Shown verbatim.
  final String label;

  final bool required;

  /// WooCommerce's ordering. The server sorts by it; this is kept so the
  /// order survives anything that rebuilds the list.
  final int priority;

  /// `text`, `tel`, `state` or `country`.
  final String type;

  /// Choices for a `state` in a country that has a state list. Empty means
  /// free text — which is the answer for the UK and the UAE, not an omission.
  final Map<String, String> options;

  /// Whether this field should be drawn as a picker rather than a text input.
  bool get isPicker => type == 'country' || options.isNotEmpty;
}

/// The whole `address-fields` answer: the country picker's choices, and the
/// form for one country.
class AddressFields {
  const AddressFields({
    required this.defaultCountry,
    required this.countries,
    required this.country,
    required this.fields,
  });

  factory AddressFields.fromJson(Map<String, dynamic> json) {
    final countries = json['countries'];
    final fields = json['fields'];

    return AddressFields(
      defaultCountry: json['default_country'] as String? ?? '',
      countries: countries is Map
          ? {
              for (final entry in countries.entries)
                '${entry.key}': '${entry.value}',
            }
          : const {},
      country: json['country'] as String? ?? '',
      fields: fields is List
          ? fields
              .whereType<Map>()
              .map((e) => AddressField.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  /// The store's base country, used for a new address.
  final String defaultCountry;

  /// Every country the store will deliver to, code to name.
  final Map<String, String> countries;

  /// Which country [fields] describes.
  final String country;

  /// The form, already in the order it should be drawn.
  final List<AddressField> fields;

  /// The descriptor for one key, or null when the country does not use it.
  ///
  /// **An absent field is the answer** — `company` is omitted in most
  /// locales — so callers skip rather than substitute a default.
  AddressField? operator [](String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }
}

/// One entry in the customer's address book, as `fmp/v1/app/me` returns it.
///
/// The field names are WooCommerce's own, minus its `billing_`/`shipping_`
/// prefix, because the server stores them that way so the mirror into
/// WooCommerce is a straight copy.
class SavedAddress {
  const SavedAddress({
    this.id,
    this.label = '',
    this.isDefault = false,
    this.firstName = '',
    this.lastName = '',
    this.company = '',
    this.address1 = '',
    this.address2 = '',
    this.city = '',
    this.state = '',
    this.postcode = '',
    this.country = '',
    this.phone = '',
    this.locality = '',
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key] as String? ?? '';

    return SavedAddress(
      // Absent on an address the app has just built and not yet saved.
      id: json['id'] as String?,
      label: read('label'),
      isDefault: json['is_default'] as bool? ?? false,
      firstName: read('first_name'),
      lastName: read('last_name'),
      company: read('company'),
      address1: read('address_1'),
      address2: read('address_2'),
      city: read('city'),
      state: read('state'),
      postcode: read('postcode'),
      country: read('country'),
      phone: read('phone'),
      locality: read('locality'),
    );
  }

  /// **Stable across edits**, so sending it back keeps the server's entry
  /// rather than orphaning whatever referenced it. Null until first saved.
  final String? id;

  /// The customer's own name for it — "Home", "Work".
  final String label;

  final bool isDefault;

  final String firstName;
  final String lastName;
  final String company;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String postcode;
  final String country;
  final String phone;

  /// "Celina, Delaware 10299", pre-rendered by the server.
  ///
  /// **Read-only, and never rebuilt in Dart**: only the server can turn a
  /// state code into its display name. It is absent on an unsaved address,
  /// which is why the card falls back to composing what it can.
  final String locality;

  /// The value of one field by the key the API uses, for the dynamic form.
  String field(String key) => switch (key) {
        'first_name' => firstName,
        'last_name' => lastName,
        'company' => company,
        'address_1' => address1,
        'address_2' => address2,
        'city' => city,
        'state' => state,
        'postcode' => postcode,
        'country' => country,
        'phone' => phone,
        _ => '',
      };

  SavedAddress withField(String key, String value) => switch (key) {
        'first_name' => copyWith(firstName: value),
        'last_name' => copyWith(lastName: value),
        'company' => copyWith(company: value),
        'address_1' => copyWith(address1: value),
        'address_2' => copyWith(address2: value),
        'city' => copyWith(city: value),
        'state' => copyWith(state: value),
        'postcode' => copyWith(postcode: value),
        'country' => copyWith(country: value),
        'phone' => copyWith(phone: value),
        _ => this,
      };

  /// What goes back to the server.
  ///
  /// `locality` is deliberately absent: the server derives it, and sending it
  /// back would invite it to become a stored field that could disagree with
  /// the address it describes.
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'label': label,
        'is_default': isDefault,
        'first_name': firstName,
        'last_name': lastName,
        'company': company,
        'address_1': address1,
        'address_2': address2,
        'city': city,
        'state': state,
        'postcode': postcode,
        'country': country,
        'phone': phone,
      };

  /// The card's bold line.
  String get title => address1.isNotEmpty ? address1 : label;

  /// The card's second line.
  ///
  /// Prefers the server's [locality]; an address being added has none yet, so
  /// it composes the parts it can rather than showing nothing. The state is a
  /// code at that point ("DE"), which is why this is only the fallback.
  String get subtitle {
    if (locality.isNotEmpty) return locality;
    final parts = [city, state, postcode].where((p) => p.isNotEmpty);
    return parts.join(' ');
  }

  SavedAddress copyWith({
    String? id,
    String? label,
    bool? isDefault,
    String? firstName,
    String? lastName,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postcode,
    String? country,
    String? phone,
    String? locality,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      company: company ?? this.company,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      postcode: postcode ?? this.postcode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      locality: locality ?? this.locality,
    );
  }
}

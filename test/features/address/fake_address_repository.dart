import 'package:food_menu/src/features/address/data/address_repository.dart';
import 'package:food_menu/src/features/address/domain/address_field.dart';
import 'package:food_menu/src/features/address/domain/saved_address.dart';

/// An [AddressRepository] that answers from memory.
///
/// [replace] mimics the plugin where it matters: it assigns an id to a new
/// entry, enforces one default, and derives `locality` — all things the real
/// server does and the app must not assume it did itself.
class FakeAddressRepository implements AddressRepository {
  FakeAddressRepository({
    List<SavedAddress> book = const [],
    AddressFields? fieldsFor,
    this.delay = Duration.zero,
  })  : book = List.of(book),
        _fields = fieldsFor ?? usFields();

  /// The book as the server holds it.
  List<SavedAddress> book;

  final AddressFields _fields;
  final Duration delay;

  /// Thrown by [all] when set.
  Object? loadError;

  /// Thrown by [replace] when set.
  Object? saveError;

  /// Thrown by [fields] when set.
  Object? fieldsError;

  /// Every call made.
  final List<String> calls = [];

  /// The book as last submitted, before the server's own normalisation.
  List<SavedAddress>? lastSubmitted;

  /// Countries [fields] was asked for, in order. A null means "the store's".
  final List<String?> requestedCountries = [];

  @override
  Future<List<SavedAddress>> all() async {
    calls.add('all');
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (loadError != null) throw loadError!;
    return List.of(book);
  }

  @override
  Future<List<SavedAddress>> replace(List<SavedAddress> addresses) async {
    calls.add('replace');
    lastSubmitted = List.of(addresses);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (saveError != null) throw saveError!;

    var nextId = 0;
    final saved = <SavedAddress>[];

    for (final address in addresses) {
      saved.add(
        address.copyWith(
          id: address.id ?? 'generated-${nextId++}',
          locality: [address.city, address.state, address.postcode]
              .where((p) => p.isNotEmpty)
              .join(' '),
        ),
      );
    }

    // The server promotes the first entry when nothing is marked default.
    if (saved.isNotEmpty && !saved.any((a) => a.isDefault)) {
      saved[0] = saved[0].copyWith(isDefault: true);
    }

    // Default first, as the server sorts it.
    saved.sort(
      (a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0),
    );

    book = saved;
    return List.of(book);
  }

  @override
  Future<AddressFields> fields({String? country}) async {
    calls.add('fields');
    requestedCountries.add(country);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fieldsError != null) throw fieldsError!;

    if (country == null || country == _fields.country) return _fields;
    // Any other country gets the no-state-list shape, so a test can prove the
    // form follows the server rather than its own idea of an address.
    return gbFields();
  }
}

SavedAddress buildAddress({
  String? id = 'addr-1',
  String label = 'Home',
  bool isDefault = false,
  String address1 = '6391 Elgin St.',
  String city = 'Celina',
  String state = 'DE',
  String postcode = '10299',
  String country = 'US',
  String firstName = 'Test',
  String lastName = 'Customer',
  String phone = '',
  String locality = 'Celina, Delaware 10299',
}) {
  return SavedAddress(
    id: id,
    label: label,
    isDefault: isDefault,
    firstName: firstName,
    lastName: lastName,
    address1: address1,
    city: city,
    state: state,
    postcode: postcode,
    country: country,
    phone: phone,
    locality: locality,
  );
}

/// The US shape: a required state **with** a list, and a required "ZIP Code".
AddressFields usFields() {
  return const AddressFields(
    defaultCountry: 'US',
    countries: {'US': 'United States', 'GB': 'United Kingdom'},
    country: 'US',
    fields: [
      AddressField(
        key: 'first_name',
        label: 'First name',
        required: true,
        priority: 10,
        type: 'text',
      ),
      AddressField(
        key: 'last_name',
        label: 'Last name',
        required: true,
        priority: 20,
        type: 'text',
      ),
      AddressField(
        key: 'country',
        label: 'Country / Region',
        required: true,
        priority: 40,
        type: 'country',
      ),
      AddressField(
        key: 'address_1',
        label: 'Street address',
        required: true,
        priority: 50,
        type: 'text',
      ),
      AddressField(
        key: 'city',
        label: 'Town / City',
        required: true,
        priority: 70,
        type: 'text',
      ),
      AddressField(
        key: 'state',
        label: 'State',
        required: true,
        priority: 80,
        type: 'state',
        options: {'DE': 'Delaware', 'CA': 'California'},
      ),
      AddressField(
        key: 'postcode',
        label: 'ZIP Code',
        required: true,
        priority: 90,
        type: 'text',
      ),
    ],
  );
}

/// The UK shape: **no state list and no required state**, and a "Postcode".
/// Also no `company`, which WooCommerce omits — an absent field is an answer.
AddressFields gbFields() {
  return const AddressFields(
    defaultCountry: 'US',
    countries: {'US': 'United States', 'GB': 'United Kingdom'},
    country: 'GB',
    fields: [
      AddressField(
        key: 'first_name',
        label: 'First name',
        required: true,
        priority: 10,
        type: 'text',
      ),
      AddressField(
        key: 'last_name',
        label: 'Last name',
        required: true,
        priority: 20,
        type: 'text',
      ),
      AddressField(
        key: 'country',
        label: 'Country / Region',
        required: true,
        priority: 40,
        type: 'country',
      ),
      AddressField(
        key: 'address_1',
        label: 'Street address',
        required: true,
        priority: 50,
        type: 'text',
      ),
      AddressField(
        key: 'city',
        label: 'Town / City',
        required: true,
        priority: 70,
        type: 'text',
      ),
      AddressField(
        key: 'state',
        label: 'County',
        required: false,
        priority: 80,
        type: 'state',
      ),
      AddressField(
        key: 'postcode',
        label: 'Postcode',
        required: true,
        priority: 90,
        type: 'text',
      ),
    ],
  );
}

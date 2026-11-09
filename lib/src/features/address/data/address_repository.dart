import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/address_field.dart';
import '../domain/saved_address.dart';

/// Talks to the address half of `fmp/v1/app/me`, and to
/// `fmp/v1/app/address-fields`.
class AddressRepository {
  const AddressRepository(this._client);

  final ApiClient _client;

  String get _me => _client.foodMenuApi('app/me');
  String get _fields => _client.foodMenuApi('app/address-fields');

  /// The customer's address book, default first.
  Future<List<SavedAddress>> all() async {
    final raw = await _client.get<Map<String, dynamic>>(_me);
    return _book(raw);
  }

  /// Replaces the **whole** book and returns it as saved.
  ///
  /// There are no per-address routes: the plugin puts the book on `PUT /me`
  /// and a mobile client always holds the full list anyway. The consequence
  /// is that an address left out of this list is deleted, so callers must
  /// send everything they want to keep — [AddressController] is what makes
  /// that safe.
  Future<List<SavedAddress>> replace(List<SavedAddress> addresses) async {
    final raw = await _client.put<Map<String, dynamic>>(
      _me,
      body: {
        'addresses': addresses.map((a) => a.toJson()).toList(growable: false),
      },
    );
    return _book(raw);
  }

  /// How to draw the form for a country, or for the store's own when null.
  Future<AddressFields> fields({String? country}) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _fields,
      query: {if (country != null && country.isNotEmpty) 'country': country},
    );
    return AddressFields.fromJson(raw);
  }

  List<SavedAddress> _book(Map<String, dynamic> raw) {
    final addresses = raw['addresses'];

    if (addresses is! List) return const [];

    return addresses
        .whereType<Map>()
        .map((e) => SavedAddress.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(apiClientProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_controller.dart';
import '../domain/address_field.dart';
import '../domain/saved_address.dart';
import 'address_repository.dart';

/// The customer's address book.
///
/// **Every write is a whole-book replace**, because that is the only shape the
/// endpoint offers. This controller exists so no screen has to think about
/// that: it holds the current book, applies one change to a copy, and sends
/// the result. A screen that built the list itself could drop an address by
/// forgetting to include it.
class AddressController extends AsyncNotifier<List<SavedAddress>> {
  @override
  Future<List<SavedAddress>> build() async {
    if (!ref.watch(isSignedInProvider)) return const [];

    return ref.read(addressRepositoryProvider).all();
  }

  /// Adds an address, or updates the one with the same id.
  ///
  /// Not optimistic, unlike the wishlist: the server validates per country and
  /// rewrites what it stores — a state code resolved from a name, a formatted
  /// postcode, a `locality` only it can build. Showing a guess and then
  /// correcting it would be worse than waiting for the real answer.
  Future<void> save(SavedAddress address) async {
    final book = await future;
    final next = [...book];
    final existing = address.id == null
        ? -1
        : next.indexWhere((a) => a.id == address.id);

    if (existing >= 0) {
      next[existing] = address;
    } else {
      next.add(address);
    }

    // Where this address ended up in what we are about to send. The server
    // reports a rejection by position in that list, so this is the only way
    // to tell "your input is wrong" from "a different saved address is".
    final sentAt = existing >= 0 ? existing : next.length - 1;

    await _replace(_withSingleDefault(next, address), sentAt: sentAt);
  }

  /// Removes an address by id.
  Future<void> remove(String id) async {
    final book = await future;
    await _replace(
      book.where((a) => a.id != id).toList(growable: false),
    );
  }

  /// Promotes one address to the default.
  Future<void> setDefault(String id) async {
    final book = await future;
    final target = book.where((a) => a.id == id).firstOrNull;

    if (target == null) return;

    await _replace(_withSingleDefault(book, target.copyWith(isDefault: true)));
  }

  /// Exactly one default, decided here rather than hoped for.
  ///
  /// The server promotes the first entry when nothing is marked, so sending
  /// two defaults would silently pick one. Clearing the flag on everything
  /// else makes the customer's choice the one that survives.
  List<SavedAddress> _withSingleDefault(
    List<SavedAddress> book,
    SavedAddress chosen,
  ) {
    if (!chosen.isDefault) return book;

    return [
      for (final address in book)
        // A new address has no id yet, so it is matched by identity.
        if (identical(address, chosen) ||
            (address.id != null && address.id == chosen.id))
          address.copyWith(isDefault: true)
        else
          address.copyWith(isDefault: false),
    ];
  }

  Future<void> _replace(List<SavedAddress> book, {int? sentAt}) async {
    try {
      final saved = await ref.read(addressRepositoryProvider).replace(book);
      state = AsyncData(saved);
    } on ApiException catch (error) {
      throw AddressSaveException.from(error, sentAt: sentAt);
    }
  }

  /// Re-reads the book.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(addressRepositoryProvider).all(),
    );
  }
}

final addressControllerProvider =
    AsyncNotifierProvider<AddressController, List<SavedAddress>>(
  AddressController.new,
  // As with the wishlist: the screen offers its own retry, and Riverpod's
  // backoff otherwise keeps a timer alive behind an error state and stops
  // `.future` ever completing with the error.
  retry: (retryCount, error) => null,
);

/// How many addresses are saved, for the Account screen's row.
final addressCountProvider = Provider<int>((ref) {
  return ref.watch(addressControllerProvider).value?.length ?? 0;
});

/// The form description for a country, keyed so switching country and back
/// does not refetch.
///
/// A null country asks for the store's own, which is what a new address wants.
final addressFieldsProvider =
    FutureProvider.family<AddressFields, String?>((ref, country) {
  return ref.watch(addressRepositoryProvider).fields(country: country);
});

/// A rejected save, with the server's complaint already placed.
///
/// The server answers `fmp_app_invalid_address` with the offending field and
/// **its index in the submitted book**. Because every write sends the whole
/// book, that index is not necessarily the address being edited: an entry
/// stored before the store changed country can fail a save of a different
/// one. Only the controller knows where it put the address it was given, so
/// it resolves that here rather than leaving the form to guess.
class AddressSaveException implements Exception {
  const AddressSaveException({
    required this.error,
    required this.field,
    required this.isThisAddress,
  });

  factory AddressSaveException.from(ApiException error, {int? sentAt}) {
    final field = error.field;
    final index = error.index;
    final isAddressError = error.code == 'fmp_app_invalid_address';

    return AddressSaveException(
      error: error,
      field: isAddressError ? field : null,
      // A rejection with no index, or one for a position we did not write to,
      // is somebody else's problem and must not light up this form's inputs.
      isThisAddress:
          isAddressError && index != null && sentAt != null && index == sentAt,
    );
  }

  final ApiException error;

  /// The rejected field's key, when the server named one.
  final String? field;

  /// Whether the rejection refers to the address this form submitted.
  final bool isThisAddress;

  String get message => error.message;
}

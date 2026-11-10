import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../address/data/address_controller.dart';
import '../../address/domain/saved_address.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../domain/checkout_contact.dart';

/// What the customer has typed or chosen on the checkout screen.
///
/// Held in a provider rather than in the screen's `State` for two reasons:
/// the address is chosen on a sheet and in the address book, which rebuild
/// the screen beneath them, and task 6.5 has to return to a checkout that
/// **kept its input** after a refused order.
///
/// Name and phone are nullable on purpose: null means *not edited*, which is
/// what lets [checkoutContactProvider] fall back to the account. An empty
/// string means the customer cleared the field, and is left cleared.
class CheckoutDetails {
  const CheckoutDetails({this.name, this.phone, this.note = '', this.addressId});

  final String? name;
  final String? phone;

  /// "Gate code, cutlery…" — always the customer's, never prefilled.
  final String note;

  /// Which saved address this order goes to, or null to follow the book's
  /// default. **An id, not the address**, so an edit to that address is
  /// picked up rather than frozen here — see [checkoutAddressProvider].
  final String? addressId;

  CheckoutDetails copyWith({
    String? name,
    String? phone,
    String? note,
    String? addressId,
  }) {
    return CheckoutDetails(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      addressId: addressId ?? this.addressId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CheckoutDetails &&
      other.name == name &&
      other.phone == phone &&
      other.note == note &&
      other.addressId == addressId;

  @override
  int get hashCode => Object.hash(name, phone, note, addressId);
}

class CheckoutController extends Notifier<CheckoutDetails> {
  @override
  CheckoutDetails build() => const CheckoutDetails();

  void setName(String name) => state = state.copyWith(name: name);

  void setPhone(String phone) => state = state.copyWith(phone: phone);

  void setNote(String note) => state = state.copyWith(note: note);

  void chooseAddress(String addressId) =>
      state = state.copyWith(addressId: addressId);
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutDetails>(
  CheckoutController.new,
);

/// The address this order goes to.
///
/// **Resolved on every read, like the order type and the slot**: a chosen id
/// that is no longer in the book — deleted, or the customer signed out and in
/// as somebody else — falls back to the book's default rather than leaving
/// the screen pointed at an address the server has never heard of. Null means
/// there is no address to use, which for a delivery order blocks it.
final checkoutAddressProvider = Provider<SavedAddress?>((ref) {
  final book = ref.watch(addressControllerProvider).value;
  if (book == null || book.isEmpty) return null;

  final chosen = ref.watch(checkoutControllerProvider).addressId;
  if (chosen != null) {
    for (final address in book) {
      if (address.id == chosen) return address;
    }
  }

  for (final address in book) {
    if (address.isDefault) return address;
  }
  return book.first;
});

/// The name and phone to show, and to submit.
///
/// Prefilled from the account, then from the chosen address, so a customer
/// who has ordered before is not asked again for what the store already
/// knows. Anything typed wins, including a cleared field.
final checkoutContactProvider = Provider<CheckoutContact>((ref) {
  final details = ref.watch(checkoutControllerProvider);
  final user = ref.watch(currentSessionProvider)?.user;
  final address = ref.watch(checkoutAddressProvider);

  return CheckoutContact(
    name: details.name ?? _accountName(user) ?? _addressName(address) ?? '',
    phone: details.phone ?? _firstNonEmpty([user?.phone, address?.phone]) ?? '',
  );
});

/// The account's own name, or null when it has none.
///
/// **Not [AuthUser.greetingName]**, which falls back to the email address:
/// that is right for a greeting and wrong in a field the kitchen prints on a
/// ticket.
String? _accountName(AuthUser? user) {
  if (user == null) return null;

  final full = [user.firstName, user.lastName]
      .where((part) => part.trim().isNotEmpty)
      .join(' ');

  return _firstNonEmpty([full, user.displayName]);
}

String? _addressName(SavedAddress? address) {
  if (address == null) return null;

  return _firstNonEmpty([
    [address.firstName, address.lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' '),
  ]);
}

String? _firstNonEmpty(List<String?> candidates) {
  for (final candidate in candidates) {
    if (candidate != null && candidate.trim().isNotEmpty) return candidate;
  }
  return null;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../address/data/address_controller.dart';
import '../../address/domain/saved_address.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../cart/data/cart_controller.dart';
import '../../fulfilment/data/fulfilment_controller.dart';
import '../../fulfilment/domain/order_types.dart';
import '../domain/checkout_contact.dart';
import '../domain/checkout_field.dart';
import '../domain/order_draft.dart';
import '../domain/payment_method.dart';
import 'checkout_repository.dart';
import 'payment_repository.dart';

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
  const CheckoutDetails({
    this.name,
    this.phone,
    this.note = '',
    this.answers = const CheckoutFieldAnswers(),
    this.addressId,
    this.paymentMethodId,
  });

  final String? name;
  final String? phone;

  /// "Gate code, cutlery…" — always the customer's, never prefilled.
  final String note;

  /// What the customer answered to the store's own checkout questions. Kept
  /// here with everything else a refused order has to hand back untouched.
  final CheckoutFieldAnswers answers;

  /// Which saved address this order goes to, or null to follow the book's
  /// default. **An id, not the address**, so an edit to that address is
  /// picked up rather than frozen here — see [checkoutAddressProvider].
  final String? addressId;

  /// The chosen gateway id, or null to follow the store's default. An id
  /// again, and resolved the same way — see [selectedPaymentMethodProvider].
  final String? paymentMethodId;

  CheckoutDetails copyWith({
    String? name,
    String? phone,
    String? note,
    CheckoutFieldAnswers? answers,
    String? addressId,
    String? paymentMethodId,
  }) {
    return CheckoutDetails(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      answers: answers ?? this.answers,
      addressId: addressId ?? this.addressId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CheckoutDetails &&
      other.name == name &&
      other.phone == phone &&
      other.note == note &&
      other.answers == answers &&
      other.addressId == addressId &&
      other.paymentMethodId == paymentMethodId;

  @override
  int get hashCode =>
      Object.hash(name, phone, note, answers, addressId, paymentMethodId);
}

class CheckoutController extends Notifier<CheckoutDetails> {
  @override
  CheckoutDetails build() => const CheckoutDetails();

  void setName(String name) => state = state.copyWith(name: name);

  void setPhone(String phone) => state = state.copyWith(phone: phone);

  void setNote(String note) => state = state.copyWith(note: note);

  void answer(CheckoutFieldAnswers answers) =>
      state = state.copyWith(answers: answers);

  void chooseAddress(String addressId) =>
      state = state.copyWith(addressId: addressId);

  void choosePayment(String methodId) =>
      state = state.copyWith(paymentMethodId: methodId);
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

/// Whether the order can be placed, and what it is.
///
/// One provider rather than a screen's worth of conditions, because the two
/// questions are the same question: everything that stops an order is a part
/// the order is missing. The screen shows [CheckoutBlocked.reason] and task
/// 6.2 submits [CheckoutReady.draft].
sealed class CheckoutReadiness {
  const CheckoutReadiness();
}

final class CheckoutReady extends CheckoutReadiness {
  const CheckoutReady(this.draft);

  final OrderDraft draft;
}

final class CheckoutBlocked extends CheckoutReadiness {
  const CheckoutBlocked(this.reason);

  /// Said to the customer as it is, so it has to name what to do.
  final String reason;
}

/// The gateway in force.
///
/// Resolved on every read, like the order type, the slot and the address: a
/// store can switch a gateway off while the screen is open, and a method the
/// app cannot complete must never reach an order. Null means there is nothing
/// this app can pay with.
final selectedPaymentMethodProvider = Provider<PaymentMethod?>((ref) {
  final methods = ref.watch(paymentMethodsProvider).value;
  if (methods == null) return null;

  return methods.resolve(
    ref.watch(checkoutControllerProvider).paymentMethodId,
    // WooCommerce's own answer for *this* cart, which is not the same as
    // what the store has enabled. Null until the cart has been read.
    ref.watch(cartControllerProvider).value?.paymentMethods,
  );
});

/// Read fresh on every attempt, never remembered: the store can switch a type
/// off, a slot can fill, and an address can be deleted while this screen is
/// open.
final checkoutReadinessProvider = Provider<CheckoutReadiness>((ref) {
  final cart = ref.watch(cartControllerProvider).value;
  if (cart == null || cart.isEmpty) {
    return const CheckoutBlocked('Your cart is empty.');
  }

  final session = ref.watch(currentSessionProvider);
  if (session == null) {
    return const CheckoutBlocked('Sign in to place your order.');
  }

  final type = ref.watch(resolvedOrderTypeProvider);
  if (type == null) {
    // Two different nulls. The store having switched ordering off is
    // permanent and worth saying plainly (task 8.7); anything else — a failed
    // request, a store mid-edit — is "right now", because it may not be.
    return CheckoutBlocked(
      ref.watch(orderingDisabledProvider)
          ? 'This restaurant is not taking online orders.'
          : 'This store is not taking orders right now.',
    );
  }

  final slots = ref.watch(slotsProvider).value;
  final slot = ref.watch(selectedSlotProvider);
  if (slots == null || slot == null) {
    return const CheckoutBlocked('Choose a time for your order.');
  }

  final address = ref.watch(checkoutAddressProvider);
  if (address == null) {
    // **Pickup needs one too.** WooCommerce validates a billing address on
    // every order and refuses one with no street or city, whatever the order
    // type — so this is not a delivery-only requirement, however the design
    // draws it. See `FINDINGS.md`.
    return CheckoutBlocked(
      type == OrderTypeKind.delivery
          ? 'Add a delivery address first.'
          : 'Add an address to your account first.',
    );
  }

  final contact = ref.watch(checkoutContactProvider);
  if (!contact.isComplete) {
    return const CheckoutBlocked('Enter a name and phone number.');
  }

  final payment = ref.watch(selectedPaymentMethodProvider);
  if (payment == null) {
    // Either the store has no gateway enabled at all, in which case the Store
    // API would refuse the order anyway, or the only ones it has need a
    // redirect this app cannot do yet.
    return const CheckoutBlocked(
      'This store has no payment method the app can use yet.',
    );
  }

  return CheckoutReady(
    OrderDraft(
      address: address,
      contact: contact,
      email: session.user.email,
      note: ref.watch(checkoutControllerProvider).note,
      // Both halves: the answers hold the values, the definitions decide
      // which key takes a list and which a string.
      fields: ref.watch(checkoutFieldsProvider),
      answers: ref.watch(checkoutControllerProvider).answers,
      type: type,
      // The server's own strings for both, never composed here.
      dateValue: slots.dateValue,
      timeValue: slot.timeValue,
      paymentMethod: payment.id,
      // What the bottom bar is showing at the moment of the tap.
      expectedTotal: '${cart.totals.totalPrice.minorUnits}',
    ),
  );
});

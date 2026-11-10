import '../../auth/domain/auth_validation.dart';

/// Client-side rules for the checkout's contact fields.
///
/// As with [AuthValidation], these exist to put a message next to a field
/// rather than to be the gate — the order route revalidates everything.
abstract final class CheckoutValidation {
  /// The design asks for one "Full name" rather than a first and last, so
  /// only presence can be checked: a one-word name is a real name in much of
  /// the world, and WooCommerce splits whatever arrives.
  static String? fullName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter the name for the order.';
    return null;
  }

  /// **Required here**, unlike on the profile, because the kitchen and the
  /// driver need a number for this specific order. The digit rule itself is
  /// [AuthValidation.optionalPhone]'s, so the two cannot drift.
  static String? phone(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter a phone number.';
    return AuthValidation.optionalPhone(value);
  }
}

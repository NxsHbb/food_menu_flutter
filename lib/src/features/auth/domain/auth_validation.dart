/// Client-side validation for the auth forms.
///
/// These mirror the server's rules rather than inventing stricter ones, so a
/// form that passes here is not then rejected by the API. Where the two could
/// drift the server stays authoritative — this layer exists to save a round
/// trip and to put the message next to the field, not to be the gate.
///
/// Pure functions, with no Flutter imports, so they are tested directly.
abstract final class AuthValidation {
  /// The server's `fmp_app_min_password_length` default.
  static const minPasswordLength = 8;

  /// Deliberately permissive. A client that rejects a valid address is a
  /// worse failure than one that lets the server have the last word, and the
  /// full grammar for an email address is not worth encoding here.
  static final _email = RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$');

  /// Returns an error message, or null when the value is acceptable.
  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(text)) return 'That does not look like an email address.';
    return null;
  }

  /// For the sign-in field, which accepts either an email or a username.
  static String? emailOrUsername(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter your email address.';
    return null;
  }

  /// Validates a new password. [email] is compared against because the server
  /// rejects a password identical to the address.
  static String? newPassword(String? value, {String? email}) {
    final text = value ?? '';
    if (text.isEmpty) return 'Choose a password.';
    if (text.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    final address = (email ?? '').trim();
    if (address.isNotEmpty && text.trim().toLowerCase() == address.toLowerCase()) {
      return 'Choose a password that is not your email address.';
    }
    return null;
  }

  /// For the sign-in field, where any non-empty value is worth submitting —
  /// an existing password predating the current rule must still work.
  static String? existingPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  /// First and last name are required at registration even though the API
  /// treats them as optional, because WooCommerce requires both on every
  /// address and the design's checkout requires a full name. Collecting them
  /// once here avoids asking again at the first order.
  static String? name(String? value, {required String field}) {
    if ((value ?? '').trim().isEmpty) return 'Enter your $field.';
    return null;
  }

  /// Phone is optional. When given, it only has to contain enough digits to
  /// be callable — the design's own checkout uses seven.
  static String? optionalPhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'That phone number looks too short.';
    return null;
  }
}

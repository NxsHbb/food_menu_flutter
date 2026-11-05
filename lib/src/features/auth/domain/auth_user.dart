/// The signed-in customer, as `fmp/v1/app` returns them.
///
/// Deliberately the same shape on every auth response — register, login,
/// refresh and `/me` all embed this object, so one parser serves all four.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.phone,
    required this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
    );
  }

  final int id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String displayName;
  final String phone;
  final String avatarUrl;

  /// What to greet the customer with.
  ///
  /// Falls back through the names the server might not have: a customer who
  /// registered without a name still gets something that is not blank.
  String get greetingName {
    final full = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (displayName.isNotEmpty) return displayName;
    return email;
  }

  /// One or two initials for the avatar fallback.
  String get initials {
    final letters = [firstName, lastName]
        .where((p) => p.isNotEmpty)
        .map((p) => p.substring(0, 1).toUpperCase())
        .take(2)
        .join();
    if (letters.isNotEmpty) return letters;
    final source = displayName.isNotEmpty ? displayName : email;
    return source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
  }

  @override
  bool operator ==(Object other) => other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

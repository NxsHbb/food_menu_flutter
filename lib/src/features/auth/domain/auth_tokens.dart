/// The bearer token pair issued by `fmp/v1/app/auth/*`.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  /// Builds tokens from a server response.
  ///
  /// The server sends lifetimes (`expires_in`), not absolute times, so they
  /// are resolved against the clock here. [now] is injectable because tests
  /// must not depend on the wall clock.
  factory AuthTokens.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final issuedAt = now ?? DateTime.now();
    final accessSeconds = (json['expires_in'] as num?)?.toInt() ?? 0;
    final refreshSeconds = (json['refresh_expires_in'] as num?)?.toInt() ?? 0;

    return AuthTokens(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      accessExpiresAt: issuedAt.add(Duration(seconds: accessSeconds)),
      refreshExpiresAt: issuedAt.add(Duration(seconds: refreshSeconds)),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;

  bool get isUsable => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  /// Whether the access token is past, or nearly past, its life.
  ///
  /// The [leeway] exists so a request is not sent with a token that expires
  /// mid-flight. Task 3.4 uses this to decide when to refresh ahead of time.
  bool accessExpired({DateTime? now, Duration leeway = const Duration(seconds: 30)}) {
    return (now ?? DateTime.now()).add(leeway).isAfter(accessExpiresAt);
  }

  bool refreshExpired({DateTime? now}) =>
      (now ?? DateTime.now()).isAfter(refreshExpiresAt);
}

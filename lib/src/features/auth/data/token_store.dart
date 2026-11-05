import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_session.dart';
import '../domain/auth_tokens.dart';
import '../domain/auth_user.dart';

/// Where the customer's session lives between launches.
///
/// Keychain on iOS, EncryptedSharedPreferences on Android — not
/// `SharedPreferences`, because a refresh token is a bearer credential valid
/// for thirty days and the plugin accepts it from anywhere.
abstract class TokenStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                // `…_this_device` so the token is never synced to iCloud or
                // restored onto a different handset: it is a bearer credential
                // the server accepts from anywhere. `first_unlock` rather than
                // `unlocked` so a session survives a reboot the customer has
                // not yet unlocked past — the app may be opened from a
                // notification before then.
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _key = 'fmp_auth_session_v1';

  @override
  Future<AuthSession?> read() async {
    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } on Exception {
      // A corrupt or unreadable keystore must not stop the app launching; the
      // worst case is the customer signs in again.
      return null;
    }

    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = _decode(json);

      // A refresh token past its life cannot recover the session, so there is
      // nothing to restore and keeping it only risks replaying it later.
      if (session == null || session.tokens.refreshExpired()) {
        await clear();
        return null;
      }

      return session;
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    final json = jsonEncode({
      'access_token': session.tokens.accessToken,
      'refresh_token': session.tokens.refreshToken,
      // Absolute, not lifetimes: the app may be closed for days, so a duration
      // captured at issue time would be meaningless on restore.
      'access_expires_at': session.tokens.accessExpiresAt.toIso8601String(),
      'refresh_expires_at': session.tokens.refreshExpiresAt.toIso8601String(),
      'user': {
        'id': session.user.id,
        'email': session.user.email,
        'username': session.user.username,
        'first_name': session.user.firstName,
        'last_name': session.user.lastName,
        'display_name': session.user.displayName,
        'phone': session.user.phone,
        'avatar_url': session.user.avatarUrl,
      },
    });

    try {
      await _storage.write(key: _key, value: json);
    } on Exception {
      // Failing to persist is not worth breaking a successful sign-in over.
      // The session stays usable for this run.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Nothing useful to do; the in-memory session is cleared regardless.
    }
  }

  AuthSession? _decode(Map<String, dynamic> json) {
    final access = json['access_token'] as String?;
    final refresh = json['refresh_token'] as String?;
    final accessAt = DateTime.tryParse(json['access_expires_at'] as String? ?? '');
    final refreshAt = DateTime.tryParse(json['refresh_expires_at'] as String? ?? '');
    final user = json['user'];

    if (access == null || refresh == null || accessAt == null || refreshAt == null) {
      return null;
    }

    return AuthSession(
      user: AuthUser.fromJson(user is Map ? user.cast<String, dynamic>() : const {}),
      tokens: AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: accessAt,
        refreshExpiresAt: refreshAt,
      ),
    );
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

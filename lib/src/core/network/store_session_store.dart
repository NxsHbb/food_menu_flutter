import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the guest cart's identity lives between launches.
///
/// **Only the `Cart-Token` is kept.** The `Nonce` is short-lived and comes
/// back on every single response, so storing it would buy nothing and risk
/// replaying a stale one; the cart token is the part that says *which* cart,
/// and losing it is what makes a cart vanish when the app is closed.
///
/// Secure storage rather than `SharedPreferences`, reusing what the auth
/// session already depends on: the token is not a login, but anyone holding
/// it can read and change that cart.
abstract class StoreSessionStore {
  /// The stored cart token, or null when there is none worth using.
  Future<String?> read();

  Future<void> write(String cartToken);

  Future<void> clear();
}

class SecureStoreSessionStore implements StoreSessionStore {
  SecureStoreSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                // Same reasoning as the auth session: never synced to iCloud
                // or restored onto another handset, and readable after a
                // reboot the customer has not yet unlocked past.
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _key = 'fmp_cart_token_v1';

  @override
  Future<String?> read() async {
    String? raw;

    try {
      raw = await _storage.read(key: _key);
    } on Exception {
      // An unreadable keystore must not stop the app launching. The worst
      // case is an empty cart.
      return null;
    }

    if (raw == null || raw.isEmpty) return null;

    // An expired token would be refused and a fresh cart issued anyway, so
    // sending it only costs a round trip and muddies the logs.
    if (isExpired(raw)) {
      await clear();
      return null;
    }

    return raw;
  }

  @override
  Future<void> write(String cartToken) async {
    try {
      await _storage.write(key: _key, value: cartToken);
    } on Exception {
      // Persistence is a convenience; the cart still works for this run.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Nothing useful to do, and nothing depends on the delete succeeding.
    }
  }

  /// Whether a cart token's own `exp` claim has passed.
  ///
  /// The Store API issues these for about two days. The claim is read rather
  /// than a local timestamp being kept alongside, because the app does not
  /// get to decide the lifetime and guessing it would eventually disagree.
  ///
  /// A token that cannot be decoded is **not** called expired: it may be a
  /// shape this build has never seen, and the server is the one entitled to
  /// refuse it.
  static bool isExpired(String token, {DateTime? now}) {
    final seconds = _expiry(token);
    if (seconds == null) return false;

    final expiry = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    );

    return !expiry.isAfter((now ?? DateTime.now()).toUtc());
  }

  static int? _expiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = jsonDecode(payload);
      if (json is! Map) return null;

      final exp = json['exp'];
      return exp is num ? exp.toInt() : null;
    } on Object {
      return null;
    }
  }
}

final storeSessionStoreProvider = Provider<StoreSessionStore>(
  (ref) => SecureStoreSessionStore(),
);

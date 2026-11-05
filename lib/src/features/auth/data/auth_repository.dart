import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';
import '../domain/auth_tokens.dart';
import '../domain/auth_user.dart';

/// Talks to `fmp/v1/app/auth/*`.
///
/// These four routes are the only ones in the app that are deliberately
/// unauthenticated, and the only ones that carry a password, so they are kept
/// apart from every other repository.
class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  String _url(String action) => _client.foodMenuApi('app/auth/$action');

  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? device,
  }) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _url('register'),
      body: {
        'email': email.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (device != null && device.isNotEmpty) 'device': device,
      },
    );
    return _session(raw);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    String? device,
  }) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _url('login'),
      body: {
        'username': username.trim(),
        'password': password,
        if (device != null && device.isNotEmpty) 'device': device,
      },
    );
    return _session(raw);
  }

  /// Exchanges a refresh token for a new pair.
  ///
  /// The server rotates on every call and revokes the session if a spent
  /// token is replayed, so callers must never run two refreshes concurrently.
  /// Task 3.4 owns that serialisation.
  Future<AuthTokens> refresh(String refreshToken) async {
    final raw = await _client.post<Map<String, dynamic>>(
      _url('refresh'),
      body: {'refresh_token': refreshToken},
    );
    return AuthTokens.fromJson(raw);
  }

  /// Ends a session server-side. Idempotent, and safe to call with a token the
  /// server has already forgotten.
  Future<void> logout({String? refreshToken, bool allDevices = false}) async {
    await _client.post<Map<String, dynamic>>(
      _url('logout'),
      body: {
        if (refreshToken != null && refreshToken.isNotEmpty)
          'refresh_token': refreshToken,
        if (allDevices) 'all_devices': true,
      },
    );
  }

  AuthSession _session(Map<String, dynamic> raw) {
    final user = raw['user'];
    return AuthSession(
      user: AuthUser.fromJson(user is Map ? user.cast<String, dynamic>() : const {}),
      tokens: AuthTokens.fromJson(raw),
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

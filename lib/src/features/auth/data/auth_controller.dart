import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../domain/auth_session.dart';
import 'auth_repository.dart';
import 'token_store.dart';

/// Who is signed in, if anyone.
///
/// The state is an [AsyncValue] because "we do not know yet" is a real state:
/// at launch the session is being read back from the keychain, and treating
/// that moment as signed-out would flash a sign-in prompt at a customer who is
/// already signed in.
///
/// `AsyncData(null)` is signed out. `AsyncData(session)` is signed in.
/// Failures from [login] and [register] are **thrown**, not stored here — a
/// rejected password is the form's business, not global state.
class AuthController extends AsyncNotifier<AuthSession?> {
  /// The in-flight refresh, if any.
  ///
  /// Every caller awaits this same future, so concurrent 401s produce exactly
  /// one refresh. That is not an optimisation: the server rotates refresh
  /// tokens and **revokes the session if a spent one is replayed**, so a
  /// second concurrent refresh would sign the customer out.
  Future<bool>? _refreshing;

  @override
  Future<AuthSession?> build() async {
    return ref.read(tokenStoreProvider).read();
  }

  /// A label the customer will see in their own session list later.
  String get _device {
    if (kIsWeb) return 'Web';
    try {
      return Platform.operatingSystem == 'ios' ? 'iPhone' : 'Android';
    } on UnsupportedError {
      return 'Mobile';
    }
  }

  AuthSession? get session => state.value;

  Future<void> _adopt(AuthSession session) async {
    await ref.read(tokenStoreProvider).write(session);
    state = AsyncData(session);
  }

  /// Creates an account and signs in. Throws [ApiException] on failure.
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final session = await ref.read(authRepositoryProvider).register(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          device: _device,
        );
    await _adopt(session);
  }

  /// Signs in. Throws [ApiException] on failure.
  Future<void> login({required String username, required String password}) async {
    final session = await ref.read(authRepositoryProvider).login(
          username: username,
          password: password,
          device: _device,
        );
    await _adopt(session);
  }

  /// Exchanges the refresh token for a new pair.
  ///
  /// Returns false when the session could not be renewed, having already
  /// signed the customer out. Safe to call concurrently — see [_refreshing].
  Future<bool> refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final current = session;

    if (current == null) return false;

    // Nothing to exchange, and sending an expired refresh token would just
    // spend a request to be told so.
    if (current.tokens.refreshExpired()) {
      await signOutLocally();
      return false;
    }

    try {
      final tokens =
          await ref.read(authRepositoryProvider).refresh(current.tokens.refreshToken);
      await _adopt(current.copyWith(tokens: tokens));
      return true;
    } on ApiException catch (error) {
      // 401 means the token is spent, revoked, or the session was burned by a
      // replay. None of those are recoverable, so sign out rather than leave
      // the customer in a state where every request fails.
      if (error.statusCode == 401) {
        await signOutLocally();
        return false;
      }

      // A network blip is not a reason to throw away a valid session; the next
      // request will try again.
      return false;
    }
  }

  /// Signs out, locally no matter what.
  ///
  /// The server call is best effort: if it fails the customer still expects to
  /// be signed out on this device. Leaving them signed in because the network
  /// blipped would be the worse outcome of the two.
  Future<void> logout({bool allDevices = false}) async {
    final current = session;

    await signOutLocally();

    if (current == null) return;

    try {
      await ref.read(authRepositoryProvider).logout(
            refreshToken: current.tokens.refreshToken,
            allDevices: allDevices,
          );
    } on Exception {
      // Deliberately swallowed — see above.
    }
  }

  /// Drops the session on this device without telling the server.
  ///
  /// Used when the server has already rejected our credentials, where a logout
  /// call would be answered with another 401.
  Future<void> signOutLocally() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }

  /// Replaces the signed-in customer's details, e.g. after a profile edit.
  Future<void> updateSession(AuthSession session) => _adopt(session);

  /// Asks for a password reset code. Returns the server's wording, which is
  /// deliberately the same whether or not the address has an account.
  Future<String> forgotPassword(String email) {
    return ref.read(authRepositoryProvider).forgotPassword(email);
  }

  /// Completes a reset and signs in. Throws [ApiException] on failure.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final session = await ref.read(authRepositoryProvider).resetPassword(
          email: email,
          code: code,
          password: password,
          device: _device,
        );
    await _adopt(session);
  }

  /// Changes the password and adopts the session that replaces the old one.
  ///
  /// The server revokes **every** session on success, this device's included,
  /// so adopting is not bookkeeping — without it the next request goes out
  /// with a token the server has already forgotten and the customer is
  /// silently signed out.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          device: _device,
        );
    await _adopt(session);
  }

  /// Changes the account email, adopting the replacement session for the same
  /// reason as [changePassword].
  Future<void> changeEmail({
    required String password,
    required String email,
  }) async {
    final session = await ref.read(authRepositoryProvider).changeEmail(
          password: password,
          email: email,
          device: _device,
        );
    await _adopt(session);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// The current session, or null when signed out **or still restoring**.
///
/// For anything that must distinguish "restoring" from "signed out" — the
/// router, a splash gate — watch [authControllerProvider] itself.
final currentSessionProvider = Provider<AuthSession?>((ref) {
  return ref.watch(authControllerProvider).value;
});

/// Convenience for the many widgets that only care whether anyone is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});

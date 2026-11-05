import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_session.dart';
import 'auth_repository.dart';

/// Who is signed in, if anyone.
///
/// `null` is the signed-out state, so there is no status flag that could
/// disagree with the session itself.
///
/// **In memory only, for now.** Task 3.4 persists the tokens to secure
/// storage and restores them at launch; until then a restart signs the
/// customer out. Nothing outside this class should hold a token, so that
/// change stays contained here.
class AuthController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  /// A label the customer will see in their own session list later.
  ///
  /// Not identifying — just enough to tell two devices apart.
  String get _device {
    if (kIsWeb) return 'Web';
    try {
      return Platform.operatingSystem == 'ios' ? 'iPhone' : 'Android';
    } on UnsupportedError {
      return 'Mobile';
    }
  }

  /// Creates an account and signs in. Throws [ApiException] on failure.
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    state = await ref.read(authRepositoryProvider).register(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          device: _device,
        );
  }

  /// Signs in. Throws [ApiException] on failure.
  Future<void> login({required String username, required String password}) async {
    state = await ref.read(authRepositoryProvider).login(
          username: username,
          password: password,
          device: _device,
        );
  }

  /// Signs out, locally no matter what.
  ///
  /// The server call is best effort: if it fails the customer still expects to
  /// be signed out on this device, and the session is revoked here either way.
  /// Leaving them signed in because the network blipped would be the worse
  /// outcome of the two.
  Future<void> logout({bool allDevices = false}) async {
    final session = state;
    state = null;

    if (session == null) return;

    try {
      await ref.read(authRepositoryProvider).logout(
            refreshToken: session.tokens.refreshToken,
            allDevices: allDevices,
          );
    } on Exception {
      // Deliberately swallowed — see above.
    }
  }

  /// Replaces the signed-in customer's details, e.g. after a profile edit.
  void updateUser(AuthSession session) => state = session;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// Convenience for the many widgets that only care whether anyone is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider) != null;
});

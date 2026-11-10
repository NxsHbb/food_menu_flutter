import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/domain/auth_session.dart';
import 'package:food_menu/src/features/auth/domain/auth_tokens.dart';
import 'package:food_menu/src/features/auth/domain/auth_user.dart';

AuthSession sessionFor({
  int id = 8,
  String email = 'customer@foodmenu.test',
  String firstName = 'Test',
  String lastName = 'Customer',
  String phone = '',
}) {
  final now = DateTime(2026, 11, 5, 12);
  return AuthSession(
    user: AuthUser(
      id: id,
      email: email,
      username: 'test.customer',
      firstName: firstName,
      lastName: lastName,
      displayName: '$firstName $lastName'.trim(),
      phone: phone,
      avatarUrl: '',
    ),
    tokens: AuthTokens(
      accessToken: 'fmpa_${id}_abc_access',
      refreshToken: 'fmpa_${id}_abc_refresh',
      accessExpiresAt: now.add(const Duration(hours: 1)),
      refreshExpiresAt: now.add(const Duration(days: 30)),
    ),
  );
}

/// Copy a user with one field changed.
AuthUser userWith(AuthUser user, {String? email}) {
  return AuthUser(
    id: user.id,
    email: email ?? user.email,
    username: user.username,
    firstName: user.firstName,
    lastName: user.lastName,
    displayName: user.displayName,
    phone: user.phone,
    avatarUrl: user.avatarUrl,
  );
}

/// An [AuthRepository] that answers from memory.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.session,
    this.loginError,
    this.registerError,
    this.logoutError,
    this.refreshError,
    this.delay = Duration.zero,
  });

  AuthSession? session;
  Object? loginError;
  Object? registerError;
  Object? logoutError;
  Object? refreshError;
  final Duration delay;

  final List<Map<String, Object?>> calls = [];

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    String? device,
  }) async {
    calls.add({'call': 'login', 'username': username, 'password': password, 'device': device});
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (loginError != null) throw loginError!;
    return session ?? sessionFor();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? device,
  }) async {
    calls.add({
      'call': 'register',
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'device': device,
    });
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (registerError != null) throw registerError!;
    return session ?? sessionFor(email: email, firstName: firstName, lastName: lastName);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    calls.add({'call': 'refresh', 'refresh_token': refreshToken});
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (refreshError != null) throw refreshError!;
    final base = session ?? sessionFor();
    return AuthTokens(
      accessToken: '${base.tokens.accessToken}_rotated',
      refreshToken: '${base.tokens.refreshToken}_rotated',
      accessExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// Thrown by the account-security calls when set.
  Object? securityError;

  /// The code [resetPassword] will accept.
  String resetCode = '123456';

  @override
  Future<String> forgotPassword(String email) async {
    calls.add({'call': 'forgot_password', 'email': email});
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (securityError != null) throw securityError!;
    // The real route says the same thing whether or not the address exists.
    return 'If that address has an account, a reset code is on its way.';
  }

  @override
  Future<AuthSession> resetPassword({
    required String email,
    required String code,
    required String password,
    String? device,
  }) async {
    calls.add({
      'call': 'reset_password',
      'email': email,
      'code': code,
      'password': password,
    });
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (securityError != null) throw securityError!;
    return _replacementFor(session ?? sessionFor(email: email));
  }

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
    String? device,
  }) async {
    calls.add({
      'call': 'change_password',
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (securityError != null) throw securityError!;
    return _replacementFor(session ?? sessionFor());
  }

  @override
  Future<AuthSession> changeEmail({
    required String password,
    required String email,
    String? device,
  }) async {
    calls.add({'call': 'change_email', 'password': password, 'email': email});
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (securityError != null) throw securityError!;
    final base = session ?? sessionFor();
    return _replacementFor(
      base.copyWith(user: userWith(base.user, email: email)),
    );
  }

  /// A session with **different tokens**, as the server returns.
  ///
  /// All four security routes revoke every existing session, so a caller that
  /// fails to adopt what comes back is holding a dead token. Handing back the
  /// same tokens would let that bug pass.
  AuthSession _replacementFor(AuthSession base) {
    return base.copyWith(
      tokens: AuthTokens(
        accessToken: '${base.tokens.accessToken}_reissued',
        refreshToken: '${base.tokens.refreshToken}_reissued',
        accessExpiresAt: base.tokens.accessExpiresAt,
        refreshExpiresAt: base.tokens.refreshExpiresAt,
      ),
    );
  }

  @override
  Future<void> logout({String? refreshToken, bool allDevices = false}) async {
    calls.add({'call': 'logout', 'refresh_token': refreshToken, 'all_devices': allDevices});
    if (logoutError != null) throw logoutError!;
  }
}

/// A [TokenStore] backed by a plain field, so tests never touch the keychain.
class FakeTokenStore implements TokenStore {
  FakeTokenStore({this.stored});

  AuthSession? stored;

  /// Every call made, so a test can assert the session was persisted or wiped
  /// rather than only that the in-memory state changed.
  final List<String> calls = [];

  @override
  Future<AuthSession?> read() async {
    calls.add('read');
    return stored;
  }

  @override
  Future<void> write(AuthSession session) async {
    calls.add('write');
    stored = session;
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    stored = null;
  }
}

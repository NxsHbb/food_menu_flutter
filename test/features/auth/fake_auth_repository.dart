import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/domain/auth_session.dart';
import 'package:food_menu/src/features/auth/domain/auth_tokens.dart';
import 'package:food_menu/src/features/auth/domain/auth_user.dart';

AuthSession sessionFor({
  int id = 8,
  String email = 'customer@foodmenu.test',
  String firstName = 'Test',
  String lastName = 'Customer',
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
      phone: '',
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

/// An [AuthRepository] that answers from memory.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.session,
    this.loginError,
    this.registerError,
    this.logoutError,
    this.delay = Duration.zero,
  });

  AuthSession? session;
  Object? loginError;
  Object? registerError;
  Object? logoutError;
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
    return (session ?? sessionFor()).tokens;
  }

  @override
  Future<void> logout({String? refreshToken, bool allDevices = false}) async {
    calls.add({'call': 'logout', 'refresh_token': refreshToken, 'all_devices': allDevices});
    if (logoutError != null) throw logoutError!;
  }
}

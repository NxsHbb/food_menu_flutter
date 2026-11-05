import 'auth_tokens.dart';
import 'auth_user.dart';

/// A signed-in customer and the tokens that prove it.
///
/// The absence of this object *is* the signed-out state, so there is no status
/// enum to keep in step with it.
class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final AuthUser user;
  final AuthTokens tokens;

  AuthSession copyWith({AuthUser? user, AuthTokens? tokens}) {
    return AuthSession(user: user ?? this.user, tokens: tokens ?? this.tokens);
  }
}

import 'package:dio/dio.dart';

/// Attaches the customer's bearer token to outgoing requests.
///
/// The plugin resolves `Authorization: Bearer fmpa_…` into the real WordPress
/// current user, so one token authenticates both the plugin's own `fmp/v1/app`
/// routes and the WooCommerce Store API calls that need a customer. That is
/// why this is a blanket interceptor rather than something each repository
/// opts into — the exceptions are named in [_unauthenticated], and are only
/// the routes that genuinely take no customer.
///
/// It only ever adds a header. Refreshing an expired token, and signing the
/// customer out when the server rejects one, belong to task 3.4 — kept out of
/// here because a refresh has to be serialised across the whole app, which an
/// interceptor cannot do on its own.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.readToken});

  /// Returns the current access token, or null when signed out.
  ///
  /// Asynchronous on purpose. At launch the session is still being read back
  /// from the keychain, and a synchronous read would report "signed out" to
  /// every request made in that window — so the first authenticated call after
  /// a cold start would silently go out without its token.
  final Future<String?> Function() readToken;

  /// The `auth/` routes that must **not** carry a token.
  ///
  /// `login` and `register` are unauthenticated, `forgot-password` and
  /// `reset-password` are deliberately public, and `refresh` and `logout`
  /// carry the refresh token in the body — an access token alongside it is at
  /// best redundant, and on `refresh` it would be an expired one.
  ///
  /// **Named one by one, rather than excluding the whole `auth/` prefix.**
  /// The prefix is not the question: `change-password`, `change-email` and
  /// `delete-account` live under it and every one of them *requires* the
  /// token. Excluding the prefix broke all three, and the suite could not see
  /// it because every test above this layer stubs `AuthRepository`.
  static const _unauthenticated = {
    'login',
    'register',
    'refresh',
    'logout',
    'forgot-password',
    'reset-password',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isUnauthenticatedRoute(options.path)) {
      final token = await readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  bool _isUnauthenticatedRoute(String path) {
    const prefix = '/fmp/v1/app/auth/';
    final start = path.indexOf(prefix);

    if (start < 0) return false;

    // The action alone: a query string or a trailing segment must not turn a
    // route that needs the token into one that does not.
    final action = path.substring(start + prefix.length).split('?').first;

    return _unauthenticated.contains(action);
  }
}

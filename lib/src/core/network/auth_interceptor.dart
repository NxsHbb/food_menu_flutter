import 'package:dio/dio.dart';

/// Attaches the customer's bearer token to outgoing requests.
///
/// The plugin resolves `Authorization: Bearer fmpa_…` into the real WordPress
/// current user, so one token authenticates both the plugin's own `fmp/v1/app`
/// routes and the WooCommerce Store API calls that need a customer. That is
/// why this is a blanket interceptor rather than something each repository
/// opts into.
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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Never on the auth routes themselves: `/login` and `/register` are
    // unauthenticated, and sending a stale token to `/refresh` or `/logout`
    // alongside the body would be at best redundant.
    if (!_isAuthRoute(options.path)) {
      final token = await readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  bool _isAuthRoute(String path) => path.contains('/fmp/v1/app/auth/');
}

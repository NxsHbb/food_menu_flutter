import 'package:dio/dio.dart';

/// Turns a 401 into one refresh and one retry, or a sign-out.
///
/// Deduplication lives in [refresh], not here. The plugin rotates refresh
/// tokens and deliberately **revokes the whole session if a spent one is
/// replayed**, so a burst of parallel 401s must produce exactly one call to
/// `/auth/refresh` — `AuthController.refresh` guarantees that with a
/// single-flight future that every caller awaits.
///
/// This is deliberately a plain [Interceptor] and **not** a
/// [QueuedInterceptor]. A queued one deadlocks: [retry] re-enters the
/// interceptor chain, and the replayed request's callbacks wait on the very
/// queue slot the error handler is still occupying. The retried request is
/// marked so it short-circuits instead of refreshing again.
///
/// Refresh is reactive, on a 401, rather than pre-emptive on a known-expired
/// token. One wasted request per hour is cheap, and it keeps a single code
/// path that has to work anyway: the server can revoke a session at any time,
/// so "the token looked valid but was not" must be handled regardless.
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required this.hasSession,
    required this.refresh,
    required this.accessToken,
    required this.retry,
  });

  /// Whether anyone is signed in. A 401 while signed out is just a 401.
  final bool Function() hasSession;

  /// Performs the refresh, returning false if the session could not be
  /// renewed. Implementations sign the customer out before returning false.
  final Future<bool> Function() refresh;

  /// The access token to replay the request with, read *after* the refresh.
  final String? Function() accessToken;

  /// Re-sends a request. It does pass through this interceptor again, which
  /// is why [_retriedKey] exists.
  final Future<Response<dynamic>> Function(RequestOptions options) retry;

  /// Marks a request as already retried, so a second 401 gives up instead of
  /// looping.
  static const _retriedKey = 'fmp_auth_retried';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    final shouldTry = err.response?.statusCode == 401 &&
        !_isAuthRoute(options.path) &&
        options.extra[_retriedKey] != true &&
        hasSession();

    if (!shouldTry) {
      handler.next(err);
      return;
    }

    final renewed = await refresh();

    if (!renewed) {
      // `refresh` has already signed the customer out. Let the original error
      // surface so the screen can react, rather than inventing a new one.
      handler.next(err);
      return;
    }

    final token = accessToken();

    if (token == null || token.isEmpty) {
      handler.next(err);
      return;
    }

    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $token';

    try {
      handler.resolve(await retry(options));
    } on DioException catch (error) {
      handler.next(error);
    }
  }

  bool _isAuthRoute(String path) => path.contains('/fmp/v1/app/auth/');
}

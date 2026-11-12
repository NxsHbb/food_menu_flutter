import 'package:dio/dio.dart';

/// Says that this request came from the mobile app.
///
/// **Why the server needs to know.** The Store API is not the app's private
/// road — the website's own block cart and checkout use it too. So a plugin
/// change that must apply to the app and *not* to the website cannot be
/// written against the Store API alone. This header is the only thing that
/// tells the two apart.
///
/// First needed by task 9.3, where a fixed cart discount is lost on every
/// Store API order. The website's block checkout has the same bug, and fixing
/// it for everyone would change what existing stores charge on a plugin
/// update — so the correction is gated on this header and the website is left
/// exactly as it was.
///
/// Unconditional, unlike the branch and order-type headers: those carry a
/// *choice*, which may not have been made yet, while this carries a fact that
/// is true of every request the app will ever send.
class AppIdentityInterceptor extends Interceptor {
  const AppIdentityInterceptor();

  static const header = 'X-FMP-App';

  /// The app's own version, so a server-side log or a future gate can tell
  /// builds apart. Kept in step with `pubspec.yaml` by hand; nothing breaks
  /// if it drifts, because the plugin only tests that the header is present.
  static const version = '1.0.0';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.headers.putIfAbsent(header, () => version);
    handler.next(options);
  }
}

import 'package:dio/dio.dart';

/// Tells the server which branch the customer is ordering from.
///
/// The plugin scopes Store API product queries by this header, the way the
/// website scopes them by a `fmp_location_id` cookie. An interceptor rather
/// than a parameter on each call: the menu, search, the collection counts and
/// the cart all have to agree about the branch, and threading it through
/// every call site is how one of them ends up disagreeing.
///
/// **Zero means store-wide** and is sent as such — it is a real answer, not
/// an absent one — while a null branch sends nothing at all.
class BranchInterceptor extends Interceptor {
  BranchInterceptor({required Future<int?> Function() read}) : _read = read;

  static const header = 'X-FMP-Branch';

  /// Async because the branch is restored from storage on a cold start, and
  /// the first menu request has to carry it. Resolving it later would show
  /// the customer every branch's dishes and then quietly swap them.
  final Future<int?> Function() _read;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.headers.containsKey(header)) {
      final branch = await _read();

      if (branch != null && branch > 0) {
        options.headers[header] = '$branch';
      }
    }

    handler.next(options);
  }
}

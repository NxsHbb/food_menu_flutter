import 'package:dio/dio.dart';

import 'store_session.dart';

/// Carries the Store API's `Nonce` and `Cart-Token` between requests.
///
/// The Store API is stateless from the client's point of view: it returns both
/// headers on **every** response and expects them back on the next write. A
/// write sent without them fails with `woocommerce_rest_missing_nonce`.
///
/// Errors are harvested too, deliberately. A 401 for a missing nonce still
/// carries a fresh `Nonce` and `Cart-Token` in its headers, so reading them
/// only from successful responses would leave a client that can never recover
/// from its first write.
class StoreSessionInterceptor extends Interceptor {
  StoreSessionInterceptor({
    required StoreSession Function() read,
    required void Function({String? nonce, String? cartToken}) write,
  })  : _read = read,
        _write = write;

  static const nonceHeader = 'Nonce';
  static const cartTokenHeader = 'Cart-Token';

  final StoreSession Function() _read;
  final void Function({String? nonce, String? cartToken}) _write;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final session = _read();
    final nonce = session.nonce;
    final cartToken = session.cartToken;

    // Never overwrite a header the caller set deliberately.
    if (nonce != null && !options.headers.containsKey(nonceHeader)) {
      options.headers[nonceHeader] = nonce;
    }
    if (cartToken != null && !options.headers.containsKey(cartTokenHeader)) {
      options.headers[cartTokenHeader] = cartToken;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _absorb(response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final headers = err.response?.headers;
    if (headers != null) _absorb(headers);
    handler.next(err);
  }

  void _absorb(Headers headers) {
    // Header lookup in dio is case-insensitive, which matters because the
    // Store API sends `Nonce` but proxies may normalise the casing.
    final nonce = headers.value(nonceHeader);
    final cartToken = headers.value(cartTokenHeader);
    if (nonce == null && cartToken == null) return;
    _write(nonce: nonce, cartToken: cartToken);
  }
}

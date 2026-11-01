import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A dio adapter that answers from a script instead of the network.
///
/// Lets the interceptor and error-mapping tests run with no server and no
/// extra dependency.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this._respond);

  /// Called for each request; returns the canned response.
  final FakeResponse Function(RequestOptions options) _respond;

  /// Every request this adapter saw, in order.
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final canned = _respond(options);
    return ResponseBody.fromString(
      jsonEncode(canned.body),
      canned.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...canned.headers.map((key, value) => MapEntry(key, [value])),
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeResponse {
  const FakeResponse({
    this.statusCode = 200,
    this.body = const <String, dynamic>{},
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final Object body;
  final Map<String, String> headers;
}

import 'package:dio/dio.dart';

/// What went wrong, at a granularity the UI can act on.
enum ApiFailure {
  /// No usable connection, DNS failure, or the host refused us.
  network,

  /// The request outlived its timeout.
  timeout,

  /// The server answered, but with an error status.
  http,

  /// The server answered successfully with a body we could not read.
  malformedResponse,

  /// The request was cancelled, usually because the screen went away.
  cancelled,

  /// Anything we have not classified.
  unknown,
}

/// A transport or server error, normalised so screens never touch `DioException`.
///
/// WordPress REST errors share one body shape regardless of endpoint:
/// `{"code": "...", "message": "...", "data": {"status": 401}}`. Both the Store
/// API and the Food Menu plugin use it, so [code] and [message] are lifted out
/// of it where present — the plugin's messages are specific enough to show.
class ApiException implements Exception {
  const ApiException({
    required this.failure,
    required this.message,
    this.statusCode,
    this.code,
    this.retryAfter,
    this.field,
    this.index,
    this.data,
  });

  final ApiFailure failure;

  /// Human-readable. The server's own message when it sent one.
  final String message;

  /// HTTP status, when the server answered at all.
  final int? statusCode;

  /// The WordPress error code, e.g. `woocommerce_rest_missing_nonce`.
  final String? code;

  /// How long to wait before retrying, from `data.retry_after` on a 429.
  ///
  /// The plugin's rate limiter reports the remaining window, which is the only
  /// way the UI can say "try again in two minutes" rather than just refusing.
  final Duration? retryAfter;

  /// The offending input, from `data.field`.
  ///
  /// The plugin's address validation names the field it rejected, so a form
  /// can put the message against the right input instead of in a banner.
  final String? field;

  /// The server's whole `data` block, when it sent one.
  ///
  /// Kept because the interesting part of a refusal is often in there and
  /// differs per route: the Store API names rejected address fields under
  /// `data.errors`, invalid parameters under `data.params`, and — on a total
  /// mismatch — hands back **the refreshed cart** under `data.cart`, which
  /// saves asking for it again. Read it through a feature's own error type
  /// rather than reaching in from a widget.
  final Map<String, dynamic>? data;

  /// Which item of a submitted list [field] belongs to, from `data.index`.
  ///
  /// The address book is saved as a whole list, so the server has to say
  /// *which* address it rejected. Without this a form editing one address
  /// would put the message on its own input when the fault was elsewhere.
  final int? index;

  /// True when retrying the identical request could plausibly succeed.
  ///
  /// A 429 is deliberately excluded: it will succeed eventually, but not now,
  /// and offering an immediate "try again" to a rate-limited customer just
  /// spends another attempt. [retryAfter] carries the wait instead.
  bool get isRetryable =>
      failure == ApiFailure.network ||
      failure == ApiFailure.timeout ||
      (statusCode != null && statusCode! >= 500);

  /// True when the server is throttling us.
  bool get isRateLimited => statusCode == 429;

  /// True when the caller should re-authenticate rather than retry.
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  /// Builds an [ApiException] from whatever dio threw.
  factory ApiException.from(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          failure: ApiFailure.timeout,
          message: 'The server took too long to respond.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server. Check your connection.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          failure: ApiFailure.cancelled,
          message: 'Request cancelled.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          failure: ApiFailure.network,
          message: 'The server certificate could not be trusted.',
        );
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(error.response);
      case DioExceptionType.unknown:
        return ApiException(
          failure: ApiFailure.unknown,
          message: error.message ?? 'Something went wrong.',
        );
    }
  }

  factory ApiException._fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final body = response?.data;

    String? serverCode;
    String? serverMessage;
    Duration? retryAfter;
    String? field;
    int? index;
    Map<String, dynamic>? details;
    if (body is Map) {
      final code = body['code'];
      final message = body['message'];
      if (code is String && code.isNotEmpty) serverCode = code;
      if (message is String && message.isNotEmpty) serverMessage = message;

      final data = body['data'];
      if (data is Map) {
        details = data.cast<String, dynamic>();
        final seconds = data['retry_after'];
        if (seconds is num && seconds > 0) {
          retryAfter = Duration(seconds: seconds.toInt());
        }
        final name = data['field'];
        if (name is String && name.isNotEmpty) field = name;
        final position = data['index'];
        if (position is num) index = position.toInt();
      }
    }

    return ApiException(
      failure: ApiFailure.http,
      message: serverMessage ?? _genericFor(status),
      statusCode: status,
      code: serverCode,
      retryAfter: retryAfter,
      field: field,
      index: index,
      data: details,
    );
  }

  static String _genericFor(int? status) {
    if (status == null) return 'The server returned an error.';
    if (status == 404) return 'That is no longer available.';
    if (status == 401 || status == 403) return 'Please sign in again.';
    if (status >= 500) return 'The server had a problem. Try again shortly.';
    return 'The server rejected the request.';
  }

  @override
  String toString() {
    final parts = [
      'ApiException(${failure.name})',
      if (statusCode != null) 'status: $statusCode',
      if (code != null) 'code: $code',
      message,
    ];
    return parts.join(' · ');
  }
}

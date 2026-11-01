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
  });

  final ApiFailure failure;

  /// Human-readable. The server's own message when it sent one.
  final String message;

  /// HTTP status, when the server answered at all.
  final int? statusCode;

  /// The WordPress error code, e.g. `woocommerce_rest_missing_nonce`.
  final String? code;

  /// True when retrying the identical request could plausibly succeed.
  bool get isRetryable =>
      failure == ApiFailure.network ||
      failure == ApiFailure.timeout ||
      (statusCode != null && statusCode! >= 500);

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
    if (body is Map) {
      final code = body['code'];
      final message = body['message'];
      if (code is String && code.isNotEmpty) serverCode = code;
      if (message is String && message.isNotEmpty) serverMessage = message;
    }

    return ApiException(
      failure: ApiFailure.http,
      message: serverMessage ?? _genericFor(status),
      statusCode: status,
      code: serverCode,
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

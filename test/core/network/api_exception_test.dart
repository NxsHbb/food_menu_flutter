import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';

void main() {
  final request = RequestOptions(path: '/cart');

  DioException badResponse(int status, {Object? body}) => DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: status,
          data: body,
        ),
      );

  group('ApiException.from', () {
    test('lifts code and message out of a WordPress REST error body', () {
      final error = ApiException.from(
        badResponse(401, body: {
          'code': 'woocommerce_rest_missing_nonce',
          'message': 'Missing the Nonce header. This endpoint requires a valid nonce.',
          'data': {'status': 401},
        }),
      );

      expect(error.failure, ApiFailure.http);
      expect(error.statusCode, 401);
      expect(error.code, 'woocommerce_rest_missing_nonce');
      expect(error.message, contains('Missing the Nonce header'));
      expect(error.isAuthFailure, isTrue);
      expect(error.isRetryable, isFalse);
    });

    test('falls back to a generic message when the body has none', () {
      final error = ApiException.from(badResponse(404));

      expect(error.statusCode, 404);
      expect(error.code, isNull);
      expect(error.message, 'That is no longer available.');
    });

    test('treats 5xx as retryable', () {
      expect(ApiException.from(badResponse(503)).isRetryable, isTrue);
    });

    test('maps timeouts', () {
      final error = ApiException.from(
        DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(error.failure, ApiFailure.timeout);
      expect(error.isRetryable, isTrue);
    });

    test('maps connection failures', () {
      final error = ApiException.from(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ),
      );

      expect(error.failure, ApiFailure.network);
      expect(error.isRetryable, isTrue);
    });

    test('maps cancellation, which is never retryable', () {
      final error = ApiException.from(
        DioException(requestOptions: request, type: DioExceptionType.cancel),
      );

      expect(error.failure, ApiFailure.cancelled);
      expect(error.isRetryable, isFalse);
    });

    test('ignores a non-map body rather than throwing', () {
      final error = ApiException.from(badResponse(500, body: '<html>oops'));

      expect(error.failure, ApiFailure.http);
      expect(error.code, isNull);
      expect(error.isRetryable, isTrue);
    });
  });
}

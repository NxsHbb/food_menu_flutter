import 'dart:io';
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

    test('a socket failure is a connection failure, not an unknown one', () {
      // dio reserves `connectionError` for a narrow set of cases. A dropped
      // Wi-Fi, a DNS failure and a server that is not running all arrive as
      // `unknown` wrapping a SocketException — which used to mean the
      // customer read "Something went wrong." and, worse, was offered no
      // retry for the one failure most likely to work on a second tap.
      final error = ApiException.from(
        DioException(
          requestOptions: request,
          type: DioExceptionType.unknown,
          error: const SocketException('Failed host lookup: shop.local'),
        ),
      );

      expect(error.failure, ApiFailure.network);
      expect(error.isRetryable, isTrue);
      expect(error.message, 'Could not reach the server. Check your connection.');
    });

    test('so is a failed TLS handshake', () {
      final error = ApiException.from(
        DioException(
          requestOptions: request,
          type: DioExceptionType.unknown,
          error: const TlsException('handshake failed'),
        ),
      );

      expect(error.failure, ApiFailure.network);
      expect(error.isRetryable, isTrue);
    });

    test('a genuine unknown still says so, and is not retried', () {
      // A bug in our own code reaches here. Calling it a connection problem
      // would send the customer to check their Wi-Fi over a null check.
      final error = ApiException.from(
        DioException(
          requestOptions: request,
          type: DioExceptionType.unknown,
          error: ArgumentError('bad state'),
          message: 'Something broke in the client.',
        ),
      );

      expect(error.failure, ApiFailure.unknown);
      expect(error.isRetryable, isFalse);
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

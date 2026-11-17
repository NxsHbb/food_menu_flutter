import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/auth_interceptor.dart';

import 'fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  String? token;

  Dio dioWith() {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    adapter = FakeAdapter((_) => FakeResponse(body: const {'ok': true}));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(readToken: () async => token));
    return dio;
  }

  setUp(() => token = null);

  test('adds no header while signed out', () async {
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me');

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('carries the bearer token once signed in', () async {
    token = 'fmpa_8_abc_secret';
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer fmpa_8_abc_secret',
    );
  });

  test('also carries it to the Store API, which shares the same identity',
      () async {
    token = 'fmpa_8_abc_secret';
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/cart');

    expect(adapter.requests.single.headers['Authorization'], isNotNull);
  });

  test('never sends a token to the auth routes that take no customer',
      () async {
    token = 'fmpa_8_abc_secret';
    final dio = dioWith();

    for (final route in [
      'login',
      'register',
      'refresh',
      'logout',
      'forgot-password',
      'reset-password',
    ]) {
      await dio.post<Map<String, dynamic>>('/wp-json/fmp/v1/app/auth/$route');
    }

    for (final request in adapter.requests) {
      expect(
        request.headers.containsKey('Authorization'),
        isFalse,
        reason: request.path,
      );
    }
  });

  test('still sends it to the auth routes that require one', () async {
    // Found on a device, not here: these three sit under `app/auth/` and the
    // interceptor used to exclude that whole prefix, so all three answered
    // "You must be signed in to do that." to a signed-in customer. Nothing
    // above this layer could catch it — every screen test stubs
    // `AuthRepository`, so no interceptor runs.
    token = 'fmpa_8_abc_secret';
    final dio = dioWith();

    for (final route in [
      'change-password',
      'change-email',
      'delete-account',
    ]) {
      await dio.post<Map<String, dynamic>>('/wp-json/fmp/v1/app/auth/$route');
    }

    for (final request in adapter.requests) {
      expect(
        request.headers['Authorization'],
        'Bearer fmpa_8_abc_secret',
        reason: request.path,
      );
    }
  });

  test('a query string cannot disguise a route that needs the token',
      () async {
    token = 'fmpa_8_abc_secret';
    final dio = dioWith();

    await dio.post<Map<String, dynamic>>(
      '/wp-json/fmp/v1/app/auth/delete-account?_locale=user',
    );

    expect(adapter.requests.single.headers['Authorization'], isNotNull);
  });

  test('an empty token is treated as no token', () async {
    token = '';
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me');

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });
}

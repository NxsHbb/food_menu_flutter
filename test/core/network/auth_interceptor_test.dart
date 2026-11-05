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
    dio.interceptors.add(AuthInterceptor(readToken: () => token));
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

  test('never sends a token to the auth routes themselves', () async {
    token = 'fmpa_8_abc_secret';
    final dio = dioWith();

    for (final route in ['login', 'register', 'refresh', 'logout']) {
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

  test('an empty token is treated as no token', () async {
    token = '';
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/fmp/v1/app/me');

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });
}

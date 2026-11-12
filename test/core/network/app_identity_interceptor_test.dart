import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/app_identity_interceptor.dart';

import 'fake_adapter.dart';

/// Task 9.3: the Store API is not the app's private road — the website's own
/// block cart and checkout use it too — so a plugin change meant for the app
/// and not the website needs this header to tell them apart.
void main() {
  late FakeAdapter adapter;

  Dio dioWith() {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    adapter = FakeAdapter((_) => FakeResponse(body: const {'ok': true}));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(const AppIdentityInterceptor());
    return dio;
  }

  test('every request says it came from the app', () async {
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/cart');

    expect(
      adapter.requests.single.headers[AppIdentityInterceptor.header],
      AppIdentityInterceptor.version,
    );
  });

  test('including the ones that carry no choice yet', () async {
    // Unlike the branch and order-type headers, this one has nothing to wait
    // for: it is true of the very first request on a cold start.
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>('/wp-json/wc/store/v1/products');
    await dio.post<Map<String, dynamic>>('/wp-json/wc/store/v1/checkout');

    expect(
      adapter.requests
          .every((r) => r.headers.containsKey(AppIdentityInterceptor.header)),
      isTrue,
    );
  });

  test('a caller that set it deliberately keeps its own value', () async {
    final dio = dioWith();
    await dio.get<Map<String, dynamic>>(
      '/wp-json/wc/store/v1/cart',
      options: Options(headers: {AppIdentityInterceptor.header: '9.9.9'}),
    );

    expect(
      adapter.requests.single.headers[AppIdentityInterceptor.header],
      '9.9.9',
    );
  });
}

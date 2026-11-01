import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/config/app_config.dart';
import 'package:food_menu/src/core/network/api_client.dart';
import 'package:food_menu/src/core/network/api_exception.dart';

import 'fake_adapter.dart';

void main() {
  const config = AppConfig(baseUrl: 'https://example.com');

  ApiClient clientFor(FakeResponse Function(RequestOptions options) respond) {
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
      ..httpClientAdapter = FakeAdapter(respond);
    return ApiClient(dio: dio, config: config);
  }

  test('builds Store API and Food Menu URLs from the site root', () {
    final client = clientFor((_) => const FakeResponse());

    expect(
      client.storeApi('cart/add-item'),
      'https://example.com/wp-json/wc/store/v1/cart/add-item',
    );
    expect(
      client.foodMenuApi('track/abc123'),
      'https://example.com/wp-json/fmp/v1/track/abc123',
    );
  });

  test('returns the decoded body on success', () async {
    final client = clientFor(
      (_) => const FakeResponse(body: {'name': 'Margherita'}),
    );

    final body = await client.get<Map<String, dynamic>>('/products/1');

    expect(body['name'], 'Margherita');
  });

  test('throws ApiException, never DioException', () async {
    final client = clientFor(
      (_) => const FakeResponse(
        statusCode: 403,
        body: {'code': 'rest_forbidden', 'message': 'Sorry, not allowed.'},
      ),
    );

    await expectLater(
      client.get<Map<String, dynamic>>('/orders'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'rest_forbidden')
            .having((e) => e.isAuthFailure, 'isAuthFailure', isTrue),
      ),
    );
  });

  test('sends the body on a post', () async {
    final seen = <Object?>[];
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
      ..httpClientAdapter = FakeAdapter((options) {
        seen.add(options.data);
        return const FakeResponse(body: {'items_count': 1});
      });
    final client = ApiClient(dio: dio, config: config);

    final body = await client.post<Map<String, dynamic>>(
      client.storeApi('cart/add-item'),
      body: {'id': 26, 'quantity': 2},
    );

    expect(seen.single, {'id': 26, 'quantity': 2});
    expect(body['items_count'], 1);
  });
}

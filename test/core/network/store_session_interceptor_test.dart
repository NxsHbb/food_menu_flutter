import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/store_session.dart';
import 'package:food_menu/src/core/network/store_session_interceptor.dart';

import 'fake_adapter.dart';

void main() {
  late StoreSession session;
  late Dio dio;
  late FakeAdapter adapter;

  /// Wires a dio whose adapter answers with [respond].
  void buildDio(FakeResponse Function(RequestOptions options) respond) {
    adapter = FakeAdapter(respond);
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        StoreSessionInterceptor(
          read: () async => session,
          write: ({String? nonce, String? cartToken}) {
            session = session.copyWith(nonce: nonce, cartToken: cartToken);
          },
        ),
      );
  }

  setUp(() => session = const StoreSession());

  test('captures Nonce and Cart-Token from a successful response', () async {
    buildDio(
      (_) => const FakeResponse(
        headers: {'Nonce': 'abc123', 'Cart-Token': 'jwt.token.here'},
      ),
    );

    await dio.get<dynamic>('/cart');

    expect(session.nonce, 'abc123');
    expect(session.cartToken, 'jwt.token.here');
    expect(session.canWrite, isTrue);
  });

  test('replays captured headers on the next request', () async {
    buildDio((_) => const FakeResponse(headers: {'Nonce': 'n1'}));

    await dio.get<dynamic>('/cart');
    await dio.get<dynamic>('/cart');

    expect(adapter.requests.first.headers.containsKey('Nonce'), isFalse);
    expect(adapter.requests.last.headers['Nonce'], 'n1');
  });

  test('captures headers from an error response too', () async {
    // The Store API answers a nonce-less write with 401 but still hands back a
    // usable Nonce. Without harvesting it, a client could never recover.
    buildDio(
      (_) => const FakeResponse(
        statusCode: 401,
        body: {
          'code': 'woocommerce_rest_missing_nonce',
          'message': 'Missing the Nonce header.',
        },
        headers: {'Nonce': 'fresh', 'Cart-Token': 'cart.jwt'},
      ),
    );

    await expectLater(
      dio.post<dynamic>('/cart/add-item'),
      throwsA(isA<DioException>()),
    );

    expect(session.nonce, 'fresh');
    expect(session.cartToken, 'cart.jwt');
  });

  test('a response carrying only one header does not erase the other',
      () async {
    session = const StoreSession(nonce: 'old', cartToken: 'keep-me');
    buildDio((_) => const FakeResponse(headers: {'Nonce': 'new'}));

    await dio.get<dynamic>('/cart');

    expect(session.nonce, 'new');
    expect(session.cartToken, 'keep-me');
  });

  test('does not overwrite a header the caller set deliberately', () async {
    session = const StoreSession(nonce: 'from-session');
    buildDio((_) => const FakeResponse());

    await dio.get<dynamic>(
      '/cart',
      options: Options(headers: {'Nonce': 'explicit'}),
    );

    expect(adapter.requests.single.headers['Nonce'], 'explicit');
  });
}

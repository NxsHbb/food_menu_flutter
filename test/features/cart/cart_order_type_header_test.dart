import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/config/app_config.dart';
import 'package:food_menu/src/core/network/api_client.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/fulfilment/domain/order_types.dart';

import '../../core/network/fake_adapter.dart';

/// Task 8.6: a pickup order must not be quoted a delivery fee.
///
/// The header is what tells the server that, and the cart has to carry it on
/// **every** route, because every one of them answers with the totals.
void main() {
  late FakeAdapter adapter;

  CartRepository repositoryFor(OrderTypeKind? kind) {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    adapter = FakeAdapter(
      (_) => const FakeResponse(
        body: {'items': <dynamic>[], 'items_count': 0, 'totals': <String, dynamic>{}},
      ),
    );
    dio.httpClientAdapter = adapter;

    return CartRepository(
      ApiClient(dio: dio, config: AppConfig.fromEnvironment()),
      orderType: kind,
    );
  }

  String? sentHeader() =>
      adapter.requests.single.headers[OrderTypeKind.header] as String?;

  test('a pickup cart says so', () async {
    final repository = repositoryFor(OrderTypeKind.pickup);
    await repository.cart();

    expect(sentHeader(), 'pickup');
  });

  test('a delivery cart says so too, so absence has one meaning', () async {
    final repository = repositoryFor(OrderTypeKind.delivery);
    await repository.cart();

    expect(sentHeader(), 'delivery');
  });

  test('sends nothing before the store has answered', () async {
    final repository = repositoryFor(null);
    await repository.cart();

    expect(
      adapter.requests.single.headers.containsKey(OrderTypeKind.header),
      isFalse,
    );
  });

  test('rides every cart route, not just the first read', () async {
    // A quantity change answers with the totals like everything else, so a
    // route without the header would put the delivery fee back on a pickup
    // order the moment the customer tapped "+".
    for (final call in <Future<void> Function(CartRepository)>[
      (r) => r.cart(),
      (r) => r.addItem(productId: 26),
      (r) => r.updateItem(key: 'abc', quantity: 2),
      (r) => r.removeItem(key: 'abc'),
      (r) => r.selectShippingRate(packageId: 0, rateId: 'flat_rate:3'),
    ]) {
      final repository = repositoryFor(OrderTypeKind.pickup);
      await call(repository);

      expect(sentHeader(), 'pickup', reason: adapter.requests.single.path);
    }
  });
}

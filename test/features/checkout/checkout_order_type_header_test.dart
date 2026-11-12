import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/config/app_config.dart';
import 'package:food_menu/src/core/network/api_client.dart';
import 'package:food_menu/src/features/checkout/data/checkout_repository.dart';
import 'package:food_menu/src/features/checkout/domain/checkout_contact.dart';
import 'package:food_menu/src/features/checkout/domain/order_draft.dart';
import 'package:food_menu/src/features/fulfilment/domain/order_types.dart';

import '../../core/network/fake_adapter.dart';
import '../address/fake_address_repository.dart';

/// Task 8.6: the order is created from the cart during `POST checkout`, so
/// this request is the last chance to say that a pickup order ships nothing.
void main() {
  late FakeAdapter adapter;

  OrderDraft draftFor(OrderTypeKind type) => OrderDraft(
        address: buildAddress(),
        contact: const CheckoutContact(name: 'Test Customer', phone: '01711'),
        email: 'customer@foodmenu.test',
        note: '',
        type: type,
        dateValue: 'November 12, 2026',
        timeValue: '',
        paymentMethod: 'cod',
        expectedTotal: '790',
      );

  CheckoutRepository repository() {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    adapter = FakeAdapter(
      (_) => const FakeResponse(body: {'order_id': 74, 'status': 'processing'}),
    );
    dio.httpClientAdapter = adapter;

    return CheckoutRepository(
      ApiClient(dio: dio, config: AppConfig.fromEnvironment()),
    );
  }

  test('a pickup order is placed as collected', () async {
    await repository().placeOrder(draftFor(OrderTypeKind.pickup));

    expect(
      adapter.requests.single.headers[OrderTypeKind.header],
      'pickup',
    );
  });

  test('a delivery order is placed as shipped', () async {
    await repository().placeOrder(draftFor(OrderTypeKind.delivery));

    expect(
      adapter.requests.single.headers[OrderTypeKind.header],
      'delivery',
    );
  });

  test('the header agrees with the type in the body', () async {
    // The two are read by different halves of the plugin — the header by the
    // cart, the extension field at order creation — and an order whose fee
    // and whose type disagreed would be the worst of both.
    final draft = draftFor(OrderTypeKind.pickup);
    await repository().placeOrder(draft);

    final request = adapter.requests.single;
    final extensions =
        (request.data as Map)['extensions'] as Map<String, dynamic>;
    final plugin = (extensions['food-menu-pro'] as Map).cast<String, dynamic>();

    expect(request.headers[OrderTypeKind.header], plugin['fmp_order_time_type']);
  });
}

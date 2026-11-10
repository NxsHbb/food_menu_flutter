export 'package:food_menu/src/features/orders/domain/customer_order.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/domain/customer_order.dart';

/// An [OrdersRepository] answering from the captured fixture.
class FakeOrdersRepository implements OrdersRepository {
  FakeOrdersRepository({CustomerOrder? order, this.delay = Duration.zero})
      : answer = order ?? orderFromFixture('order_delivery');

  CustomerOrder answer;
  final Duration delay;

  /// Thrown by the next call, then cleared.
  Object? failNext;

  /// Every id asked for, in order.
  final List<int> requested = [];

  @override
  Future<CustomerOrder> order(int id) async {
    requested.add(id);
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return answer;
  }
}

CustomerOrder orderFromFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return CustomerOrder.fromJson(json as Map<String, dynamic>);
}

export 'package:food_menu/src/features/checkout/domain/payment_method.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/features/checkout/data/payment_repository.dart';
import 'package:food_menu/src/features/checkout/domain/payment_method.dart';

/// A [PaymentRepository] answering from the captured fixtures.
class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository({PaymentMethods? methods, this.delay = Duration.zero})
      : answer = methods ?? paymentMethodsFromFixture('payment_methods');

  PaymentMethods answer;
  final Duration delay;

  /// Thrown by the next call, then cleared.
  Object? failNext;

  int calls = 0;

  @override
  Future<PaymentMethods> methods() async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return answer;
  }
}

PaymentMethods paymentMethodsFromFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return PaymentMethods.fromJson(json as Map<String, dynamic>);
}

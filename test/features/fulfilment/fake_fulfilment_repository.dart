export 'package:food_menu/src/features/fulfilment/domain/order_types.dart';
export 'package:food_menu/src/features/fulfilment/domain/slots.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/features/fulfilment/data/fulfilment_repository.dart';
import 'package:food_menu/src/features/fulfilment/domain/order_types.dart';
import 'package:food_menu/src/features/fulfilment/domain/slots.dart';

/// A [FulfilmentRepository] answering from the captured fixtures.
///
/// Slot answers are keyed by order type, because the whole point of the
/// feature is that the two differ — pickup offers point times and delivery
/// offers windows, on their own hours.
class FakeFulfilmentRepository implements FulfilmentRepository {
  FakeFulfilmentRepository({
    OrderTypes? types,
    Map<OrderTypeKind, SlotList>? slotsByType,
    this.delay = Duration.zero,
  })  : types = types ?? orderTypesFromFixture('order_types'),
        slotsByType = slotsByType ??
            {
              OrderTypeKind.pickup: slotsFromFixture('slots_pickup'),
              OrderTypeKind.delivery: slotsFromFixture('slots_delivery'),
            };

  OrderTypes types;
  Map<OrderTypeKind, SlotList> slotsByType;
  final Duration delay;

  /// Thrown by the next call of any kind, then cleared.
  Object? failNext;

  /// Thrown by the next slot read only, so a test can fail the times without
  /// failing the order types the screen needs first.
  Object? failNextSlots;

  /// Every call made, as `'order-types 0'` or `'slots pickup 2026-11-10 14:2'`.
  final List<String> calls = [];

  Future<void> _tick() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<OrderTypes> orderTypes({int branch = 0}) async {
    calls.add('order-types $branch');
    await _tick();
    return types;
  }

  @override
  Future<SlotList> slots({
    required OrderTypeKind type,
    String? date,
    int branch = 0,
    String items = '',
  }) async {
    calls.add(
      'slots ${type.name} ${date ?? '-'} ${items.isEmpty ? '-' : items}',
    );
    await _tick();

    final failure = failNextSlots;
    if (failure != null) {
      failNextSlots = null;
      throw failure;
    }

    final answer = slotsByType[type];
    if (answer == null) {
      throw StateError('no slots seeded for ${type.name}');
    }
    return answer;
  }
}

Map<String, dynamic> _fixture(String name) {
  return jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
      as Map<String, dynamic>;
}

OrderTypes orderTypesFromFixture(String name) =>
    OrderTypes.fromJson(_fixture(name));

SlotList slotsFromFixture(String name) => SlotList.fromJson(_fixture(name));

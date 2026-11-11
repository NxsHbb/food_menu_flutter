export 'package:food_menu/src/features/orders/domain/customer_order.dart';
export 'package:food_menu/src/features/orders/domain/order_summary.dart';
export 'package:food_menu/src/features/orders/domain/order_tracking.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/core/network/paged.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/domain/customer_order.dart';
import 'package:food_menu/src/features/orders/domain/order_summary.dart';
import 'package:food_menu/src/features/orders/domain/order_tracking.dart';

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

  /// What [tracking] answers. Defaults to an order partway through a
  /// four-stage pipeline, which is the design's own case.
  OrderTracking trackingAnswer = trackingFixture();

  /// Every id [tracking] was asked for, in order.
  final List<int> trackingRequested = [];

  /// Thrown by the next [tracking], then cleared.
  Object? failNextTracking;

  @override
  Future<OrderTracking> tracking(int id) async {
    trackingRequested.add(id);
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNextTracking;
    if (failure != null) {
      failNextTracking = null;
      throw failure;
    }
    return trackingAnswer;
  }

  /// What [orders] answers, per group. A group with no entry is empty.
  final Map<OrderGroup, List<OrderSummary>> history = {};

  /// Every `(group, page)` asked for, in order.
  final List<({OrderGroup group, int page})> historyCalls = [];

  /// Thrown by the next [orders], then cleared.
  Object? failNextHistory;

  /// Pretend page size, so pagination can be exercised with a short list.
  int pageSize = 10;

  @override
  Future<Paged<OrderSummary>> orders({
    required OrderGroup group,
    int page = 1,
  }) async {
    historyCalls.add((group: group, page: page));
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = failNextHistory;
    if (failure != null) {
      failNextHistory = null;
      throw failure;
    }

    final all = history[group] ?? const <OrderSummary>[];
    final start = (page - 1) * pageSize;
    final items = start >= all.length
        ? const <OrderSummary>[]
        : all.sublist(start, (start + pageSize).clamp(0, all.length));

    return Paged(
      items: items,
      total: all.length,
      totalPages: all.isEmpty ? 0 : ((all.length - 1) ~/ pageSize) + 1,
      page: page,
    );
  }
}

/// Tracking for one order, as the server shapes it.
///
/// [stages] is `(status, label, reached)` so a test can describe a pipeline in
/// one line. `step` is derived from it, exactly as the server derives it: the
/// index of the last reached stage.
OrderTracking trackingFixture({
  int orderId = 1048,
  String status = 'prepping',
  String statusLabel = 'Prepping',
  String statusColor = '#f59e0b',
  bool isActive = true,
  bool isFailed = false,
  bool hasTimeline = true,
  String note = '',
  List<(String, String, bool)> stages = const [
    ('processing', 'Processing', true),
    ('prepping', 'Prepping', true),
    ('ready', 'Ready', false),
    ('completed', 'Completed', false),
  ],
}) {
  var step = -1;
  for (final (index, stage) in stages.indexed) {
    if (stage.$3) step = index;
  }

  return OrderTracking.fromJson({
    'order_id': orderId,
    'number': '$orderId',
    'status': status,
    'status_label': statusLabel,
    'status_color': statusColor,
    'is_active': isActive,
    'is_failed': isFailed,
    'step': step,
    'timeline': hasTimeline,
    'stages': [
      for (final (index, (slug, label, reached)) in stages.indexed)
        {
          'status': slug,
          'label': label,
          'color': '#2563eb',
          'reached': reached,
          'at': reached ? 'November 10, 2026 at 8:59 am' : '',
          'at_utc': reached ? '2026-11-10T08:59:40Z' : '',
          // On the stage the order is on, as a store's own note would be.
          'note': index == step ? note : '',
        },
    ],
  });
}

/// A history row, with only what a test cares about spelled out.
OrderSummary summaryFixture({
  int id = 1048,
  String? number,
  String status = 'processing',
  String statusLabel = 'Processing',
  String statusColor = '#2563eb',
  bool isActive = true,
  String type = 'delivery',
  String typeLabel = 'Delivery',
  String eta = 'ASAP',
  int itemCount = 2,
  String total = '1995',
  Map<String, Object?>? progress,
  DateTime? createdAt,
  List<OrderRowItem> items = const [],
}) {
  return OrderSummary.fromJson({
    'id': id,
    'number': number ?? '$id',
    'status': status,
    'status_label': statusLabel,
    'status_color': statusColor,
    'is_active': isActive,
    'date_created': (createdAt ?? DateTime(2026, 11, 10, 14, 2)).toIso8601String(),
    'type': type,
    'type_label': typeLabel,
    'eta': eta,
    'item_count': itemCount,
    'progress': progress,
    'items': [
      for (final item in items)
        {
          'id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'image': item.image,
        },
    ],
    'total_price': total,
    'currency': const {
      'currency_code': 'USD',
      'currency_symbol': r'$',
      'currency_minor_unit': 2,
      'currency_decimal_separator': '.',
      'currency_thousand_separator': ',',
      'currency_prefix': r'$',
      'currency_suffix': '',
    },
  });
}

CustomerOrder orderFromFixture(String name) =>
    CustomerOrder.fromJson(jsonFixture(name));

/// A captured payload, for a test that wants to change a field or two before
/// parsing it.
Map<String, dynamic> jsonFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return json as Map<String, dynamic>;
}

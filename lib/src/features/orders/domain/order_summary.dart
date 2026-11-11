import '../../../core/store_api/models/currency.dart';
import '../../../core/store_api/models/money.dart';

/// One row of the order history — `GET fmp/v1/app/orders`.
///
/// Deliberately **not** a [CustomerOrder]. The list route sends a summary:
/// enough for the design's row, and none of the address, customer or per-line
/// add-ons that only the detail screen draws. Opening an order reads
/// `/app/orders/{id}` for the rest.
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.isActive,
    required this.createdAt,
    required this.type,
    required this.typeLabel,
    required this.eta,
    required this.progress,
    required this.itemCount,
    required this.items,
    required this.total,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromJson(
      (json['currency'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final items = json['items'];

    return OrderSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      number: json['number']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      statusColor: json['status_color'] as String? ?? '',
      // Absent means finished, which is the safer way round to be wrong: an
      // order wrongly called active shows a live strip that never moves.
      isActive: json['is_active'] == true,
      createdAt: DateTime.tryParse(json['date_created'] as String? ?? ''),
      type: json['type'] as String? ?? '',
      typeLabel: json['type_label'] as String? ?? '',
      eta: json['eta'] as String? ?? '',
      progress: OrderProgress.tryFromJson(json['progress']),
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      items: items is List
          ? items
              .whereType<Map>()
              .map((e) => OrderRowItem.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
      total: Money.parseOrZero(json['total_price'], currency),
    );
  }

  final int id;

  /// The store's own number, which an order-number plugin can make anything.
  final String number;

  final String status;
  final String statusLabel;

  /// The store's colour for the status pill, as `#rrggbb`. May be empty for a
  /// status the plugin has no metadata for.
  final String statusColor;

  /// Whether the order is still happening. **The plugin decides this**, not
  /// the slug: a store can invent statuses and this app would have no opinion
  /// about them. See `CONTEXT.md`.
  final bool isActive;

  final DateTime? createdAt;
  final String type;
  final String typeLabel;

  /// The chosen time, or the store's ASAP estimate. Only drawn while active.
  final String eta;

  /// How far through its stages the order is, for the design's progress strip.
  ///
  /// On the **row** rather than behind a tracking request per row, which a
  /// page of ten would have cost. Null when there is nothing to draw a strip
  /// from: the store has the timeline off, or the order predates it.
  final OrderProgress? progress;

  /// Units, not lines, so three of one dish reads as three.
  final int itemCount;

  /// The first few lines, for the row's thumbnails. **Capped by the server**,
  /// so this is not the whole order — [itemCount] is the real number.
  final List<OrderRowItem> items;

  final Money total;
}

/// How far through its stages an order is, as a history row sees it.
///
/// The row gets two numbers and no labels — it draws a bar, not a timeline.
/// Opening the order reads `/app/orders/{id}/tracking` for the stages
/// themselves.
class OrderProgress {
  const OrderProgress({required this.step, required this.stageCount});

  /// Null for anything that is not a usable pair, so a store with the
  /// timeline off simply has no strip rather than one stuck at zero.
  static OrderProgress? tryFromJson(Object? raw) {
    if (raw is! Map) return null;

    final json = raw.cast<String, dynamic>();
    final step = (json['step'] as num?)?.toInt();
    final count = (json['stage_count'] as num?)?.toInt();

    if (step == null || count == null || count <= 0 || step < 0) return null;

    return OrderProgress(step: step, stageCount: count);
  }

  /// Index of the furthest stage reached.
  final int step;

  /// How many stages the order has in all.
  final int stageCount;

  /// How far along to fill the strip, 0–1.
  ///
  /// A one-stage order that has reached it is full, which also keeps the
  /// divisor off zero.
  double get fraction {
    if (stageCount <= 1) return 1;

    return (step / (stageCount - 1)).clamp(0, 1).toDouble();
  }
}

/// One line of a history row: enough for a thumbnail, and no more.
class OrderRowItem {
  const OrderRowItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.image,
  });

  factory OrderRowItem.fromJson(Map<String, dynamic> json) {
    return OrderRowItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      image: json['image'] as String? ?? '',
    );
  }

  final int id;
  final String name;
  final int quantity;
  final String image;
}

/// Which tab of the design's order history a request is for.
enum OrderGroup {
  /// Still happening — the plugin's definition, not a list of slugs.
  active('active'),

  /// Done, one way or another.
  past('past');

  const OrderGroup(this.value);

  /// What `?group=` takes.
  final String value;
}

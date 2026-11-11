/// What an order would add to a cart — `GET fmp/v1/app/orders/{id}/reorder`.
///
/// **The server decides what can be reordered, not the app.** An order line
/// records its add-ons as display text, so a selection cannot be rebuilt from
/// one; the plugin keeps the submitted payload on the line instead and hands
/// it back here. A line placed before that existed comes back unavailable with
/// a reason rather than silently reduced to its dish.
///
/// Nothing is added by reading this. The lines go to the Store API's own
/// `cart/add-item`, which is where add-on validation, branch scoping, timed
/// products and stock already work — so a dish that has gone out of stock
/// since, or a group that has become required, fails exactly as it would on a
/// first order.
class Reorder {
  const Reorder({
    required this.orderId,
    required this.number,
    required this.lines,
    required this.any,
    required this.all,
  });

  factory Reorder.fromJson(Map<String, dynamic> json) {
    final lines = json['lines'];

    return Reorder(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      number: json['number']?.toString() ?? '',
      lines: lines is List
          ? lines
              .whereType<Map>()
              .map((e) => ReorderLine.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
      any: json['any'] == true,
      all: json['all'] == true,
    );
  }

  final int orderId;
  final String number;
  final List<ReorderLine> lines;

  /// Whether anything at all can go back in the cart. The button is pointless
  /// without it.
  final bool any;

  /// Whether **everything** can. False means the customer is about to get
  /// part of their order, and has to be told which part.
  final bool all;

  List<ReorderLine> get available =>
      lines.where((line) => line.available).toList(growable: false);

  List<ReorderLine> get unavailable =>
      lines.where((line) => !line.available).toList(growable: false);
}

/// One line of an order, as the cart would take it back.
class ReorderLine {
  const ReorderLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.addons,
    required this.available,
    required this.reason,
  });

  factory ReorderLine.fromJson(Map<String, dynamic> json) {
    final addons = json['addons'];

    return ReorderLine(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      // Passed back to `cart/add-item` untouched. The app never reads inside
      // it: it is the plugin's own payload, and reshaping it here would be a
      // second place for the add-on contract to drift.
      addons: addons is List
          ? addons
              .whereType<Map>()
              .map((e) => e.cast<String, Object>())
              .toList(growable: false)
          : const [],
      available: json['available'] == true,
      reason: ReorderRefusal.from(json['reason'] as String? ?? ''),
    );
  }

  final int productId;

  /// The dish's name **now**, not as the order recorded it — a renamed dish
  /// should read as the thing the customer is about to order again.
  final String name;

  final int quantity;
  final List<Map<String, Object>> addons;
  final bool available;

  /// Why not, when [available] is false.
  final ReorderRefusal reason;
}

/// Why a line cannot go back in the cart.
enum ReorderRefusal {
  /// It can.
  none(''),

  /// The dish has been deleted from the store.
  gone('gone'),

  /// It exists but is no longer for sale.
  unavailable('unavailable'),

  /// It is for sale and there is none left.
  outOfStock('out_of_stock'),

  /// The line was placed before the plugin recorded a re-submittable
  /// selection, and the dish takes choices — so the order knows *that*
  /// add-ons were picked but not *which*.
  choicesNotRecorded('choices_not_recorded');

  const ReorderRefusal(this.value);

  final String value;

  static ReorderRefusal from(String value) {
    for (final refusal in ReorderRefusal.values) {
      if (refusal.value == value) return refusal;
    }
    // An unknown reason is still a refusal; it just has no better words than
    // the catch-all. Better than treating it as available.
    return ReorderRefusal.unavailable;
  }

  /// What to tell the customer, in their terms rather than the store's.
  String get message => switch (this) {
        ReorderRefusal.none => '',
        ReorderRefusal.gone => 'no longer on the menu',
        ReorderRefusal.unavailable => 'not available right now',
        ReorderRefusal.outOfStock => 'out of stock',
        ReorderRefusal.choicesNotRecorded => 'your choices were not saved',
      };
}

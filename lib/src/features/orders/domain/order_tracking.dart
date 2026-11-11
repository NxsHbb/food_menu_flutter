/// Where an order has got to — `GET fmp/v1/app/orders/{id}/tracking`.
///
/// **Not the public `fmp/v1/track/{token}`** the website's own tracking page
/// reads, though the app has the token for it. That route answers the entries
/// that *happened* and nothing else — every one `completed` — because the
/// website draws a history, not a plan, and the design's progress strip needs
/// the stages still to come as well. It also expires with
/// `fmp_tracking_link_expiry_days`, which is right for a link emailed to
/// whoever placed the order and wrong for the customer's own order in their
/// own signed-in app. See `CONTEXT.md`.
///
/// The app never decides how far along an order is. [step] and [stages] come
/// from the store's own declared status pipeline, for the same reason the
/// status pill takes its colour from the server: a store can invent statuses
/// and this app would have no opinion about them.
class OrderTracking {
  const OrderTracking({
    required this.orderId,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.isActive,
    required this.isFailed,
    required this.step,
    required this.stages,
    required this.hasTimeline,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    final stages = json['stages'];

    return OrderTracking(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      number: json['number']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      statusColor: json['status_color'] as String? ?? '',
      isActive: json['is_active'] == true,
      isFailed: json['is_failed'] == true,
      // -1 when nothing has been recorded, which is the server's own signal
      // and not a missing field.
      step: (json['step'] as num?)?.toInt() ?? -1,
      stages: stages is List
          ? stages
              .whereType<Map>()
              .map((e) => OrderStage.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
      hasTimeline: json['timeline'] == true,
    );
  }

  final int orderId;
  final String number;
  final String status;
  final String statusLabel;

  /// `#rrggbb` for the current status. May be empty.
  final String statusColor;

  final bool isActive;

  /// Cancelled, refunded or failed — an ending without the food arriving.
  ///
  /// Distinct from `!isActive`, which a delivered order is too. The design
  /// greys the whole strip out for one of these rather than drawing progress
  /// through it.
  final bool isFailed;

  /// Index into [stages] of the furthest stage reached, or -1 for none.
  final int step;

  /// Reached stages first, in the order they happened, then the ones still to
  /// come. **Not always four**: a store that never described a pipeline has
  /// two — where the order is, and completed.
  final List<OrderStage> stages;

  /// False when the store has the order timeline switched off, or the order
  /// predates it. [stages] is then empty, and the screen says there is no
  /// history rather than drawing an empty one.
  final bool hasTimeline;

  /// How far along to fill the design's progress strip, 0–1.
  ///
  /// A failed order fills nothing: the strip is a promise about food on its
  /// way, and a cancelled order has none coming. A single-stage order that
  /// has reached its only stage is full, which avoids dividing by zero.
  double get progress {
    if (isFailed || step < 0 || stages.isEmpty) return 0;
    if (stages.length == 1) return 1;

    return step / (stages.length - 1);
  }

  /// The stage the order is on, or null before anything was recorded.
  OrderStage? get current =>
      step >= 0 && step < stages.length ? stages[step] : null;
}

/// One stage of an order: a status the store recorded, or one still to come.
class OrderStage {
  const OrderStage({
    required this.status,
    required this.label,
    required this.color,
    required this.reached,
    required this.at,
    required this.note,
  });

  factory OrderStage.fromJson(Map<String, dynamic> json) {
    return OrderStage(
      status: json['status'] as String? ?? '',
      label: json['label'] as String? ?? '',
      color: json['color'] as String? ?? '',
      reached: json['reached'] == true,
      at: json['at'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  final String status;

  /// The store's own words for the status, translated server-side.
  final String label;

  /// `#rrggbb`. May be empty for a status the store has no colour for.
  final String color;

  final bool reached;

  /// When it was reached, **already formatted in the restaurant's time zone**
  /// and the site's own format. Empty for a stage still to come.
  ///
  /// A string and not a [DateTime] on purpose: "Ready at 9:33 pm" is only
  /// meaningful on the kitchen's clock, so the server renders it and the app
  /// does not re-zone it onto the phone's. The payload carries a UTC instant
  /// too, which nothing needs yet.
  final String at;

  /// The store's note for this stage. Empty unless `fmp_tracking_show_notes`
  /// is on, which the server decides — the app just draws what arrives.
  final String note;
}

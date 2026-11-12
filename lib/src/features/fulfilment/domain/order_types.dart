/// Which order types a store offers, and when — `GET fmp/v1/app/order-types`.
///
/// Only **pickup and delivery** ever arrive. The plugin has dine-in and the
/// design has no screen for it, so the server does not send it.
///
/// Nothing here is recomputed from parts the server already decided:
/// `firstDate` has the lead days applied, `lastDate` is null for no bound, and
/// a day is closed only when the server says `open: false`.
library;

/// The two types the app can render.
enum OrderTypeKind {
  pickup,
  delivery;

  /// The header that tells the Store API which of these an order is.
  ///
  /// **A pickup order is not a shipped one, and WooCommerce has no way to
  /// know that.** It prices shipping whenever the cart holds a shippable
  /// product, and the Food Menu order type is read from the checkout POST,
  /// long after the totals were worked out — so a customer who chose a
  /// delivery rate and then switched to pickup kept the fee, and the app hid
  /// the Delivery method section while still charging it. Pro reads this
  /// header and answers `needs_shipping: false` for a pickup cart.
  ///
  /// Sent by the cart and the checkout, which are the requests whose answers
  /// carry money. Not by the menu, which does not depend on it.
  static const header = 'X-FMP-Order-Type';

  static OrderTypeKind? tryParse(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

class OrderTypes {
  const OrderTypes({
    required this.branch,
    required this.timezone,
    required this.today,
    required this.preorderMaxDays,
    required this.slotLimitsEnabled,
    required this.types,
  });

  factory OrderTypes.fromJson(Map<String, dynamic> json) {
    final raw = json['types'];

    return OrderTypes(
      branch: (json['branch'] as num?)?.toInt() ?? 0,
      timezone: json['timezone'] as String? ?? '',
      today: json['today'] as String? ?? '',
      preorderMaxDays: (json['preorder_max_days'] as num?)?.toInt() ?? 0,
      slotLimitsEnabled: json['slot_limits_enabled'] == true,
      types: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => OrderTypeOption.tryParse(e.cast<String, dynamic>()))
              .nonNulls
              .toList(growable: false)
          : const [],
    );
  }

  /// The branch this describes. **Check it** rather than assuming the branch
  /// asked for was honoured: a store not running branches answers store-wide
  /// with 0.
  final int branch;

  /// The store's timezone, as an offset or a name. Shown nowhere; kept so a
  /// mismatch with the device is debuggable.
  final String timezone;

  /// The store's own idea of today, `Y-m-d`. Compared against a slot's date
  /// rather than the device clock, which may be in another zone.
  final String today;

  /// How far ahead a customer may order. Zero means today only.
  final int preorderMaxDays;

  /// Whether the store caps orders per slot at all. When false a slot's
  /// `remaining` means nothing.
  final bool slotLimitsEnabled;

  /// In the order the server sent them.
  final List<OrderTypeOption> types;

  OrderTypeOption? option(OrderTypeKind kind) {
    for (final type in types) {
      if (type.kind == kind) return type;
    }
    return null;
  }

  /// The types a customer may actually choose between. A store can switch
  /// either off, and a store with neither takes no orders at all.
  List<OrderTypeOption> get offered =>
      types.where((type) => type.enabled).toList(growable: false);

  /// The type in force, given what the customer has chosen.
  ///
  /// A choice the store **no longer offers is dropped**: a store can switch a
  /// type off while a screen is open, and continuing to show it would offer a
  /// way to order that the server will refuse. Null means this store takes no
  /// orders at all right now.
  OrderTypeKind? resolve(OrderTypeKind? chosen) {
    if (chosen != null && option(chosen)?.enabled == true) return chosen;
    return defaultKind;
  }

  /// What to select when the customer has not chosen.
  ///
  /// Delivery first, as the design's checkout opens on it — but only if the
  /// store offers it, so a pickup-only shop opens on pickup instead of on a
  /// type it cannot fulfil.
  OrderTypeKind? get defaultKind {
    final offeredTypes = offered;
    if (offeredTypes.isEmpty) return null;

    for (final type in offeredTypes) {
      if (type.kind == OrderTypeKind.delivery) return type.kind;
    }
    return offeredTypes.first.kind;
  }
}

/// One order type and its weekly schedule.
class OrderTypeOption {
  const OrderTypeOption({
    required this.kind,
    required this.label,
    required this.enabled,
    required this.timeRequired,
    required this.timeInterval,
    required this.leadDays,
    required this.firstDate,
    required this.lastDate,
    required this.maxOrdersPerSlot,
    required this.days,
  });

  /// Null for a type this app cannot render, so an unknown one is dropped
  /// rather than drawn as a blank tab.
  static OrderTypeOption? tryParse(Map<String, dynamic> json) {
    final kind = OrderTypeKind.tryParse(json['type'] as String?);
    if (kind == null) return null;

    final days = json['days'];

    return OrderTypeOption(
      kind: kind,
      label: json['label'] as String? ?? '',
      enabled: json['enabled'] == true,
      timeRequired: json['time_required'] == true,
      timeInterval: (json['time_interval'] as num?)?.toInt() ?? 0,
      leadDays: (json['lead_days'] as num?)?.toInt() ?? 0,
      firstDate: json['first_date'] as String? ?? '',
      lastDate: json['last_date'] as String?,
      maxOrdersPerSlot: (json['max_orders_per_slot'] as num?)?.toInt() ?? 0,
      days: days is List
          ? days
              .whereType<Map>()
              .map((e) => ScheduleDay.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  final OrderTypeKind kind;

  /// The store's own word for it, translated server-side. Shown as given.
  final String label;

  final bool enabled;

  /// When false the customer picks **no date or time at all** — the order is
  /// as soon as possible. The slot list then holds the single ASAP entry, so
  /// hide the date and draw that one row.
  final bool timeRequired;

  /// Minutes between one selectable time and the next.
  final int timeInterval;

  /// Days the kitchen needs before it can take this type. Already applied to
  /// [firstDate]; here only so a screen can explain the wait.
  final int leadDays;

  /// Earliest date this type can be fulfilled on, `Y-m-d`.
  final String firstDate;

  /// Latest, or **null for no bound** — not "today".
  final String? lastDate;

  /// Zero means no cap. Only meaningful when the store counts slots.
  final int maxOrdersPerSlot;

  /// One entry per weekday, in the store's own day order.
  final List<ScheduleDay> days;
}

/// One day of the week.
class ScheduleDay {
  const ScheduleDay({
    required this.day,
    required this.name,
    required this.open,
    required this.windows,
  });

  factory ScheduleDay.fromJson(Map<String, dynamic> json) {
    final windows = json['windows'];

    return ScheduleDay(
      day: (json['day'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      open: json['open'] == true,
      windows: windows is List
          ? windows
              .whereType<Map>()
              .map((e) => ScheduleWindow.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  /// 0 for Sunday, matching both the server and `DateTime.weekday % 7`.
  final int day;

  /// The weekday name in the store's language.
  final String name;

  /// **The only thing that means closed.** An open day with no [windows] is a
  /// day the store set no hours for, which means no restriction.
  final bool open;

  final List<ScheduleWindow> windows;
}

/// One opening window, as 24-hour `HH:mm`.
class ScheduleWindow {
  const ScheduleWindow({required this.start, required this.end});

  factory ScheduleWindow.fromJson(Map<String, dynamic> json) {
    return ScheduleWindow(
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }

  final String start;
  final String end;
}

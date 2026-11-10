import 'order_types.dart';

/// The times a customer may choose on one date — `GET fmp/v1/app/slots`.
///
/// The server generates and judges the list; nothing here decides whether a
/// slot is pickable. Past times never arrive, full ones arrive marked
/// unavailable, and each one carries the store's own words for why.
class SlotList {
  const SlotList({
    required this.branch,
    required this.type,
    required this.label,
    required this.enabled,
    required this.timeRequired,
    required this.date,
    required this.dateValue,
    required this.firstDate,
    required this.lastDate,
    required this.interval,
    required this.slotLimitsEnabled,
    required this.closedReason,
    required this.message,
    required this.slots,
  });

  factory SlotList.fromJson(Map<String, dynamic> json) {
    final raw = json['slots'];

    return SlotList(
      branch: (json['branch'] as num?)?.toInt() ?? 0,
      type: OrderTypeKind.tryParse(json['type'] as String?) ??
          OrderTypeKind.pickup,
      label: json['label'] as String? ?? '',
      enabled: json['enabled'] == true,
      timeRequired: json['time_required'] == true,
      date: json['date'] as String? ?? '',
      dateValue: json['date_value'] as String? ?? '',
      firstDate: json['first_date'] as String? ?? '',
      lastDate: json['last_date'] as String?,
      interval: (json['interval'] as num?)?.toInt() ?? 0,
      slotLimitsEnabled: json['slot_limits_enabled'] == true,
      closedReason: SlotClosedReason.tryParse(json['closed_reason'] as String?),
      message: json['message'] as String?,
      slots: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Slot.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  final int branch;
  final OrderTypeKind type;

  /// The store's own word for the type, for the section title.
  final String label;

  final bool enabled;

  /// False means no date or time is chosen at all; [slots] then holds the
  /// single ASAP entry.
  final bool timeRequired;

  /// The date this describes, `Y-m-d`. For display and comparison only.
  final String date;

  /// **The string to submit** as `fmp_{type}_date`, in the site's own display
  /// format. Never build this locally — see `CONTEXT.md`.
  final String dateValue;

  final String firstDate;
  final String? lastDate;

  /// Minutes between one slot and the next.
  final int interval;

  final bool slotLimitsEnabled;

  /// Why there is nothing to choose, when [slots] is empty.
  final SlotClosedReason? closedReason;

  /// The store's own explanation, already translated. Show it rather than
  /// composing one from [closedReason].
  final String? message;

  /// Earliest first, with ASAP leading when it applies.
  final List<Slot> slots;

  bool get isEmpty => slots.isEmpty;

  /// The slot a screen should treat as chosen.
  ///
  /// Resolved rather than stored, so a selection cannot outlive the thing it
  /// pointed at: adding a dish to the cart or waiting past a time can make a
  /// slot unavailable or drop it from the list, and the choice then falls back
  /// to the earliest one that is still open instead of silently submitting a
  /// slot the server has stopped offering.
  Slot? resolve(int? startMinutes) {
    if (startMinutes != null) {
      for (final slot in slots) {
        if (slot.startMinutes == startMinutes && slot.available) return slot;
      }
    }
    return firstAvailable;
  }

  Slot? get firstAvailable {
    for (final slot in slots) {
      if (slot.available) return slot;
    }
    return null;
  }
}

/// Why a date has no slots at all.
enum SlotClosedReason {
  typeDisabled,
  beforeFirstDate,
  afterLastDate,
  weeklyClosed,
  noTimesLeft;

  static const _wire = {
    'type_disabled': typeDisabled,
    'before_first_date': beforeFirstDate,
    'after_last_date': afterLastDate,
    'weekly_closed': weeklyClosed,
    'no_times_left': noTimesLeft,
  };

  /// Null for absent **and** for a reason this version does not know, because
  /// the accompanying message is what gets shown either way.
  static SlotClosedReason? tryParse(String? raw) => _wire[raw];
}

/// One choosable time.
class Slot {
  const Slot({
    required this.asap,
    required this.label,
    required this.timeValue,
    required this.start,
    required this.end,
    required this.startMinutes,
    required this.available,
    required this.remaining,
    required this.reason,
    required this.message,
    required this.products,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    final products = json['products'];

    return Slot(
      asap: json['asap'] == true,
      label: json['label'] as String? ?? '',
      timeValue: json['value'] as String? ?? '',
      start: json['start'] as String?,
      end: json['end'] as String?,
      startMinutes: (json['start_minutes'] as num?)?.toInt() ?? -1,
      available: json['available'] == true,
      remaining: (json['remaining'] as num?)?.toInt(),
      reason: SlotUnavailableReason.tryParse(json['reason'] as String?),
      message: json['message'] as String?,
      products: products is List
          ? products
              .whereType<Map>()
              .map((e) => BlockedProduct.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  /// "As soon as possible". Present only when it genuinely applies, so render
  /// what arrives rather than adding one.
  final bool asap;

  /// Ready to draw — a point time for pickup, a window for delivery, in the
  /// store's own format.
  final String label;

  /// **The string to submit** as `fmp_{type}_time`. Empty for [asap], which
  /// means send no time at all.
  final String timeValue;

  /// 24-hour `HH:mm`, null for [asap]. For sorting and display, never for
  /// submission.
  final String? start;
  final String? end;

  /// Minutes since midnight, and -1 for [asap]. The slot's identity within a
  /// day, since [timeValue] is empty for ASAP.
  final int startMinutes;

  final bool available;

  /// Orders still free in this slot, or null when the store caps nothing.
  final int? remaining;

  /// Why it cannot be picked. For branching only — show [message].
  final SlotUnavailableReason? reason;

  /// The store's own words, already translated.
  final String? message;

  /// Which cart dishes stand in the way, when that is the reason.
  final List<BlockedProduct> products;
}

/// Why one slot cannot be picked.
enum SlotUnavailableReason {
  /// The slot has taken as many orders as the store allows.
  full,

  /// A dish in the cart is not served at that hour.
  notServed,

  /// A dish in the cart has sold out of that slot.
  soldOut;

  static const _wire = {
    'full': full,
    'not_served': notServed,
    'sold_out': soldOut,
  };

  static SlotUnavailableReason? tryParse(String? raw) => _wire[raw];
}

/// A cart dish blocking a slot.
class BlockedProduct {
  const BlockedProduct({
    required this.id,
    required this.name,
    required this.remaining,
    required this.message,
  });

  factory BlockedProduct.fromJson(Map<String, dynamic> json) {
    return BlockedProduct(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
    );
  }

  /// The **parent** dish, which is not necessarily the cart line's own id:
  /// the server resolves a variation to the dish its limits are set on.
  final int id;
  final String name;

  /// Units still available in the slot, zero when none are.
  final int remaining;

  /// The store's own words, naming the dish.
  final String message;
}

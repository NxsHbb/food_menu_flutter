import '../../../core/store_api/models/currency.dart';
import '../../../core/store_api/models/money.dart';
import 'order_tracking.dart';

/// One of the customer's own orders — `GET fmp/v1/app/orders/{id}`.
///
/// **Read back from the server, never built from what was submitted.** The
/// checkout's own response echoes the plugin's extension schema with its
/// defaults rather than the saved order, and a store can renumber, reprice or
/// re-status an order between the post and the screen.
class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.isActive,
    required this.createdAt,
    required this.type,
    required this.typeLabel,
    required this.date,
    required this.time,
    required this.eta,
    required this.locationName,
    required this.paymentMethod,
    required this.paymentMethodTitle,
    required this.needsPayment,
    required this.customerNote,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.trackingToken,
    required this.totals,
    required this.items,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromJson(
      (json['currency'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final customer = (json['customer'] as Map?)?.cast<String, dynamic>() ?? {};
    final location = (json['location'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = json['items'];

    return CustomerOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      number: json['number']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      statusColor: json['status_color'] as String? ?? '',
      isActive: json['is_active'] == true,
      createdAt: DateTime.tryParse(json['date_created'] as String? ?? ''),
      type: json['type'] as String? ?? '',
      typeLabel: json['type_label'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      eta: json['eta'] as String? ?? '',
      locationName: location['name'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      paymentMethodTitle: json['payment_method_title'] as String? ?? '',
      needsPayment: json['needs_payment'] == true,
      customerNote: json['customer_note'] as String? ?? '',
      customerName: customer['name'] as String? ?? '',
      customerPhone: customer['phone'] as String? ?? '',
      address: (json['address'] as Map?)?.cast<String, dynamic>() ?? const {},
      trackingToken: json['tracking_token'] as String? ?? '',
      totals: OrderTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
        currency,
      ),
      items: items is List
          ? items
              .whereType<Map>()
              .map((e) => OrderItem.fromJson(e.cast<String, dynamic>(), currency))
              .toList(growable: false)
          : const [],
    );
  }

  final int id;

  /// The store's own number, which an order-number plugin can make anything.
  final String number;

  /// WooCommerce's slug. Branch on [statusLabel] for words — a store can add
  /// statuses of its own, and this app would have no name for them.
  final String status;
  final String statusLabel;

  /// The store's colour for the status pill, as `#rrggbb`. The same field the
  /// history row uses, so the pill is drawn once and looks the same in both
  /// places.
  final String statusColor;

  /// Whether the order is still happening, as the plugin defines it.
  final bool isActive;

  final DateTime? createdAt;

  /// `pickup` or `delivery`, and the store's own word for it.
  final String type;
  final String typeLabel;

  /// As stored at checkout, in the site's display format. Empty [time] is an
  /// ASAP order — the plugin has no "ASAP" value to store.
  final String date;
  final String time;

  /// What to show under "Estimated": the chosen time, or the store's own ASAP
  /// estimate. Composed server-side so it cannot disagree with the slot list.
  final String eta;

  /// The date this order is for, but **only when it needed choosing**.
  ///
  /// Empty for an ASAP order, which has no time and so no day to be wrong
  /// about. Since task 8.4 a customer can order days ahead, and a bare
  /// "12:00 am" on the received screen then reads as tonight. In the store's
  /// own display format, as it was stored.
  String get scheduledDate => time.isEmpty ? '' : date;

  /// The branch, when the store runs them.
  final String locationName;

  final String paymentMethod;
  final String paymentMethodTitle;

  /// True for a gateway still waiting on money — cash on delivery is not.
  final bool needsPayment;

  final String customerNote;
  final String customerName;
  final String customerPhone;

  /// WooCommerce's own field names, minus the `billing_`/`shipping_` prefix,
  /// the same shape a saved address uses.
  final Map<String, dynamic> address;

  /// The key to the **website's** public tracking page, and nothing the app
  /// reads. Task 7.3 tracks through `/app/orders/{id}/tracking` instead, which
  /// is bearer-authed and does not expire — see [OrderTracking] for why.
  ///
  /// Kept because it is the only way to hand someone else a link to an order,
  /// which no screen does yet. **Empty until the first status change writes
  /// one**, so anything using it must not assume there is one.
  ///
  /// There was a `canTrack` getter here, gating tracking on this token. It
  /// was removed with 7.3: tracking no longer needs the token, so a getter
  /// saying otherwise would have withheld the button from exactly the orders
  /// that can be tracked perfectly well.
  final String trackingToken;

  final OrderTotals totals;
  final List<OrderItem> items;

  bool get exists => id > 0;

  /// The customer's first name, for the design's "Thanks, …" line.
  String get firstName {
    final parts = customerName.trim().split(' ');
    return parts.isEmpty ? '' : parts.first;
  }

  /// The one-line address, for the screens that show where it is going.
  String get addressLine {
    final parts = [
      address['address_1'],
      address['address_2'],
      address['city'],
      address['postcode'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty);

    return parts.join(', ');
  }
}

/// What the order came to. The same rows the cart has, so the customer can
/// compare them line for line.
class OrderTotals {
  const OrderTotals({
    required this.totalItems,
    required this.totalDiscount,
    required this.totalShipping,
    required this.totalFees,
    required this.totalTax,
    required this.totalPrice,
    required this.currency,
  });

  factory OrderTotals.fromJson(Map<String, dynamic> json, Currency currency) {
    return OrderTotals(
      totalItems: Money.parseOrZero(json['total_items'], currency),
      totalDiscount: Money.parseOrZero(json['total_discount'], currency),
      totalShipping: Money.parseOrZero(json['total_shipping'], currency),
      totalFees: Money.parseOrZero(json['total_fees'], currency),
      totalTax: Money.parseOrZero(json['total_tax'], currency),
      totalPrice: Money.parseOrZero(json['total_price'], currency),
      currency: currency,
    );
  }

  final Money totalItems;
  final Money totalDiscount;

  /// Zero rather than null, unlike the cart's: an order has been charged, so
  /// its delivery total is decided one way or the other.
  final Money totalShipping;
  final Money totalFees;
  final Money totalTax;
  final Money totalPrice;
  final Currency currency;

  bool get hasDiscount => !totalDiscount.isZero;
}

/// One line of the order.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.total,
    required this.image,
    required this.meta,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json, Currency currency) {
    final meta = json['meta'];

    return OrderItem(
      // Zero for a dish since deleted, which is why a tap through has to
      // check before navigating.
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      total: Money.parseOrZero(json['total'], currency),
      image: json['image'] as String? ?? '',
      meta: meta is List
          ? meta
              .whereType<Map>()
              .map((e) => OrderItemMeta.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  final int id;
  final String name;
  final int quantity;
  final Money total;
  final String image;

  /// The line's own display copy, which is where the chosen add-ons are
  /// recorded — the order keeps them as text, not as ids.
  final List<OrderItemMeta> meta;

  /// The add-ons on one line, as one sentence.
  String get metaSummary => meta.map((e) => e.value).join(' · ');
}

/// One name/value pair on a line.
class OrderItemMeta {
  const OrderItemMeta({required this.label, required this.value});

  factory OrderItemMeta.fromJson(Map<String, dynamic> json) {
    return OrderItemMeta(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  final String label;
  final String value;
}

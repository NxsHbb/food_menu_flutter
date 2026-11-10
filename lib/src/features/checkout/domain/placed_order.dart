/// An order as `POST wc/store/v1/checkout` answers with it.
///
/// Deliberately thin. The response also echoes the cart and the addresses,
/// but an order that exists is read back from the server rather than
/// reconstructed from what was sent — task 6.4 does exactly that, with [id]
/// and [key], which is why both are kept.
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.number,
    required this.key,
    required this.status,
    required this.customerId,
    required this.payment,
  });

  factory PlacedOrder.fromJson(Map<String, dynamic> json) {
    final payment = json['payment_result'];

    return PlacedOrder(
      id: (json['order_id'] as num?)?.toInt() ?? 0,
      // A string, and **not** the id: a store running an order-number plugin
      // prints something else entirely on the receipt.
      number: json['order_number']?.toString() ?? '',
      key: json['order_key'] as String? ?? '',
      status: json['status'] as String? ?? '',
      // 0 for a guest. The app only orders signed in, so anything else means
      // the bearer token did not reach the Store API.
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      payment: payment is Map
          ? PaymentResult.fromJson(payment.cast<String, dynamic>())
          : null,
    );
  }

  final int id;
  final String number;
  final String key;

  /// WooCommerce's own status slug — `processing`, `on-hold`, or one of the
  /// store's custom ones. Never branched on here; the server decides what an
  /// order type and a gateway lead to.
  final String status;

  final int customerId;

  /// Null when the order needed no payment at all.
  final PaymentResult? payment;

  /// Whether this is an order at all. A response with no id is a refusal the
  /// server dressed as a success.
  bool get exists => id > 0;

  /// What to show the customer: the store's number if it has one.
  String get reference => number.isNotEmpty ? number : '$id';
}

/// What the gateway made of it.
class PaymentResult {
  const PaymentResult({required this.status, required this.redirectUrl});

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      status: json['payment_status'] as String? ?? '',
      redirectUrl: json['redirect_url'] as String? ?? '',
    );
  }

  /// `success`, `pending`, `failure` or `error`.
  final String status;

  /// Where a gateway wants the customer sent. Empty for cash on delivery,
  /// and the reason card and PayPal are a phase of their own.
  final String redirectUrl;

  bool get isSuccess => status == 'success' || status == 'pending';
}

/// What a navigation inside the payment screen means (task 12.4).
///
/// The webview sees every URL the gateway walks through — the store's
/// order-pay page, the gateway's own host, a bank's 3-D Secure form, and
/// finally the store again. Only three of those matter.
enum PaymentNavigation {
  /// Let the webview load it. The ordinary case.
  allow,

  /// The customer is back on the store, done or cancelled. Close the screen
  /// and let the **order** say which it was — the URL is a hint, never the
  /// answer.
  finished,

  /// Not a web page at all. A UPI intent, a banking app, a `tel:` link: a
  /// webview cannot open these and silently fails on them, so they go to the
  /// system instead.
  delegate,
}

/// Classifies one navigation request.
///
/// **Deliberately a pure function.** The real test of a payment flow is a
/// device with a gateway on the other end, and this is the one part of it
/// that can be pinned down in a unit test instead.
///
/// [storeHost] is the host the app talks to. It is what makes "the customer
/// is back on the shop" answerable: a gateway's cancel link does not
/// announce itself, and PayPal's lands on the **cart page** with nothing in
/// the URL to say what happened. Without it the webview cheerfully renders
/// the shop's website inside the app and the customer is stranded there —
/// which is exactly what it did on the first device run.
PaymentNavigation classifyPaymentUrl(Uri url, {String? storeHost}) {
  final scheme = url.scheme.toLowerCase();

  // `about:blank` is what a webview loads before anything else.
  if (scheme == 'about') return PaymentNavigation.allow;

  if (scheme != 'http' && scheme != 'https') return PaymentNavigation.delegate;

  final path = url.path.toLowerCase();

  // WooCommerce's own landing page after a successful payment. Matched on the
  // path rather than the host, because this one is worth catching even on a
  // store whose host the app got wrong.
  if (path.contains('order-received')) return PaymentNavigation.finished;

  // And its cancel link, which comes back to the store with the order intact.
  final cancelled = url.queryParameters.entries.any(
    (e) =>
        e.key.toLowerCase() == 'cancel_order' && e.value.toLowerCase() != 'false',
  );
  if (cancelled) return PaymentNavigation.finished;

  // Back on the shop, anywhere that is not the page the payment started on.
  // Gateways return to whatever the store told them to — `order-received`,
  // the cart, the checkout, the home page — and any of those means the
  // payment is over, one way or the other. The **order** then says which.
  if (storeHost != null && _sameHost(url.host, storeHost)) {
    return path.contains('order-pay')
        ? PaymentNavigation.allow
        : PaymentNavigation.finished;
  }

  return PaymentNavigation.allow;
}

/// Hosts match on the name alone: a store can be served from `example.com`
/// and redirect through `www.example.com`, and one is not a different shop.
bool _sameHost(String a, String b) {
  String bare(String host) {
    final lower = host.toLowerCase();
    return lower.startsWith('www.') ? lower.substring(4) : lower;
  }

  return bare(a) == bare(b);
}

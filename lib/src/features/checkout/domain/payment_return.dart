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
PaymentNavigation classifyPaymentUrl(Uri url) {
  final scheme = url.scheme.toLowerCase();

  // `about:blank` is what a webview loads before anything else.
  if (scheme == 'about') return PaymentNavigation.allow;

  if (scheme != 'http' && scheme != 'https') return PaymentNavigation.delegate;

  final path = url.path.toLowerCase();

  // WooCommerce's own landing page after a successful payment.
  if (path.contains('order-received')) return PaymentNavigation.finished;

  // And its cancel link, which comes back to the store with the order intact.
  final cancelled = url.queryParameters.entries.any(
    (e) =>
        e.key.toLowerCase() == 'cancel_order' &&
        e.value.toLowerCase() != 'false',
  );
  if (cancelled) return PaymentNavigation.finished;

  return PaymentNavigation.allow;
}

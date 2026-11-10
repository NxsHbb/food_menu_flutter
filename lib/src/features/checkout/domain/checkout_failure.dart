import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/cart.dart';
import '../../../core/util/html_text.dart';

/// Why an order was refused, and what the customer can do about it.
///
/// The Store API refuses in several shapes and the difference matters: a bad
/// postcode is fixed on this screen, a dropped connection is fixed by trying
/// again, and a price that moved is not the customer's fault at all. One
/// sentence in a snackbar cannot say which, so the refusal is classified
/// here and the screen shows it until it is dealt with.
enum CheckoutFailureKind {
  /// Nothing reached the server, or it broke. The identical order is worth
  /// sending again.
  connection,

  /// Something submitted was rejected — usually an address field. The
  /// customer fixes it here.
  validation,

  /// The cart is not what the app thought: emptied elsewhere, a dish gone, or
  /// a total that moved. The summary has to catch up before trying again.
  cart,

  /// The gateway refused, or the store stopped accepting it.
  payment,

  /// The session is no longer good. Signing in again is the only way on.
  auth,

  /// Anything unclassified. The server's own sentence is shown as it is.
  unknown,
}

class CheckoutFailure {
  const CheckoutFailure({
    required this.kind,
    required this.message,
    this.details = const [],
    this.refreshedCart,
    this.canRetry = false,
  });

  /// Classifies whatever the route threw.
  factory CheckoutFailure.from(ApiException error) {
    final kind = _kindOf(error);

    return CheckoutFailure(
      kind: kind,
      // **Through `plainText`.** WooCommerce entity-escapes its own messages,
      // so a total-mismatch sentence arrives with `&#036;` where the currency
      // symbol should be.
      message: plainText(error.message),
      details: _detailsOf(error),
      refreshedCart: _refreshedCart(error),
      // A 429 is excluded by `isRetryable`, deliberately: it will work later,
      // but not now, and offering a button spends another attempt.
      canRetry: kind == CheckoutFailureKind.connection && error.isRetryable,
    );
  }

  final CheckoutFailureKind kind;

  /// The server's own sentence, which is almost always better than one
  /// composed here — it names the field, the dish or the gateway.
  final String message;

  /// The per-field complaints, when the server listed them. Shown under the
  /// message rather than instead of it.
  final List<String> details;

  /// The cart as the server now has it, when the refusal carried one.
  final Cart? refreshedCart;

  /// Whether sending the identical order again could work.
  final bool canRetry;

  /// Whether the cart on screen is now known to be out of date.
  bool get staleCart => kind == CheckoutFailureKind.cart;

  static CheckoutFailureKind _kindOf(ApiException error) {
    if (error.failure == ApiFailure.network ||
        error.failure == ApiFailure.timeout) {
      return CheckoutFailureKind.connection;
    }

    if (error.isAuthFailure) return CheckoutFailureKind.auth;

    final code = error.code ?? '';

    // Checked before the generic 5xx arm: a 409 total mismatch is a server
    // answer, not a server fault.
    if (code.contains('cart_empty') ||
        code.contains('total_mismatch') ||
        code.contains('out_of_stock') ||
        code.contains('not_purchasable') ||
        code.contains('cart_item')) {
      return CheckoutFailureKind.cart;
    }

    if (code.contains('payment')) return CheckoutFailureKind.payment;

    if (code.contains('invalid_address') ||
        code.contains('invalid_param') ||
        code.contains('missing_callback_param') ||
        code.contains('invalid_email')) {
      return CheckoutFailureKind.validation;
    }

    final status = error.statusCode;
    if (status != null && status >= 500) return CheckoutFailureKind.connection;

    return CheckoutFailureKind.unknown;
  }

  /// The sentences the server attached to a refusal.
  ///
  /// Two shapes, both from the Store API: `data.errors` is a map of address
  /// group to a list of complaints — `{billing: ["Street address is
  /// required"]}` — and `data.params` is a map of parameter to one sentence.
  static List<String> _detailsOf(ApiException error) {
    final data = error.data;
    if (data == null) return const [];

    final found = <String>[];

    final errors = data['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List) {
          found.addAll(value.map((e) => plainText(e.toString())));
        } else if (value != null) {
          found.add(plainText(value.toString()));
        }
      }
    }

    final params = data['params'];
    if (params is Map) {
      found.addAll(params.values.map((e) => plainText(e.toString())));
    }

    // The message often repeats them, which would read as a stutter.
    return found
        .where((detail) => detail.isNotEmpty)
        .where((detail) => !plainText(error.message).contains(detail))
        .toSet()
        .toList(growable: false);
  }

  /// The refreshed cart a 409 carries, so the summary can catch up without
  /// another request.
  static Cart? _refreshedCart(ApiException error) {
    final cart = error.data?['cart'];
    if (cart is! Map) return null;

    try {
      return Cart.fromJson(cart.cast<String, dynamic>());
    } on Object {
      // A cart we cannot parse is no worse than no cart: the screen re-reads
      // it instead. Never let this turn a refusal into a crash.
      return null;
    }
  }
}

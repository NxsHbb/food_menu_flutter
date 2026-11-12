import 'checkout_field.dart';

/// Which parts of the checkout the store wants drawn (task 10.2).
///
/// **Everything true on a store that says nothing**, which is what the server
/// sends when the plugin's custom checkout is off — and what an older plugin,
/// or a failed request, resolves to here. The app keeps the checkout it has
/// unless a store has actively asked for less.
///
/// Three of the website's eight toggles are deliberately absent, and
/// `FINDINGS.md` has the reasoning: `show_additional_info` arrives separately
/// as the fields' own `enabled`, `show_shipping_address` cannot be honoured
/// without leaving a delivery order with no address, and `show_coupon` and
/// `show_order_bumps` govern features that are v2.
class CheckoutSections {
  const CheckoutSections({
    required this.orderType,
    required this.yourLocation,
    required this.orderNotes,
    required this.tips,
  });

  static const all = CheckoutSections(
    orderType: true,
    yourLocation: true,
    orderNotes: true,
    tips: true,
  );

  factory CheckoutSections.fromJson(Map<String, dynamic> json) {
    // Absent means shown, per key: a half-written payload must not empty the
    // checkout.
    bool on(String key) => json[key] != false;

    return CheckoutSections(
      orderType: on('order_type'),
      yourLocation: on('your_location'),
      orderNotes: on('order_notes'),
      tips: on('tips'),
    );
  }

  /// The pickup/delivery switch.
  final bool orderType;

  /// The branch card. False on a single-branch store, where it has nothing
  /// to say — the server already folds that in.
  final bool yourLocation;

  final bool orderNotes;

  /// **Narrows task 9.4, never widens it.** The tip row still has to pass the
  /// store's own `enable_tip` / `allow_tip_for` / `show_tip_form` rules,
  /// which arrive on the cart; this can only take it away.
  final bool tips;
}

/// The store's own words for the checkout.
///
/// Empty where the store set nothing, and the app keeps its own wording then
/// — printing a blank heading or an unlabelled button would be worse than
/// having no setting at all.
///
/// **Not gated on the custom checkout**, unlike [CheckoutSections]. These are
/// content, not layout: a store that typed its terms meant them whatever
/// template renders them.
class CheckoutTexts {
  const CheckoutTexts({
    this.heading = '',
    this.terms = '',
    this.placeOrder = '',
  });

  static const none = CheckoutTexts();

  factory CheckoutTexts.fromJson(Map<String, dynamic> json) {
    return CheckoutTexts(
      heading: (json['heading'] as String? ?? '').trim(),
      terms: (json['terms'] as String? ?? '').trim(),
      placeOrder: (json['place_order'] as String? ?? '').trim(),
    );
  }

  final String heading;

  /// What the customer is told they are agreeing to. The app has always
  /// printed a sentence of its own here; this is the store's, where it has
  /// one.
  final String terms;

  final String placeOrder;
}

/// Everything `GET fmp/v1/app/checkout-fields` answers.
class CheckoutConfig {
  const CheckoutConfig({
    required this.fields,
    required this.sections,
    required this.texts,
  });

  static const empty = CheckoutConfig(
    fields: [],
    sections: CheckoutSections.all,
    texts: CheckoutTexts.none,
  );

  final List<CheckoutField> fields;
  final CheckoutSections sections;
  final CheckoutTexts texts;
}

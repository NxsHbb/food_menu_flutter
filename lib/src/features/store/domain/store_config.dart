import 'package:material_ui/material_ui.dart';

/// The store, as `GET fmp/v1/app/config` describes it (task 14.3).
///
/// Read once at launch. **Nothing in here is allowed to be the answer to a
/// question that has to be fresh** — the kitchen's pause is the worked
/// example, and it stays on `/order-types`, which the checkout re-reads. A
/// launch-time payload would still be saying "open" twenty minutes after
/// someone shut the kitchen.
class StoreConfig {
  const StoreConfig({
    required this.name,
    required this.logoUrl,
    required this.primaryColor,
    required this.orderingEnabled,
    required this.currency,
    this.privacyPolicyUrl = '',
    this.termsUrl = '',
  });

  /// The answer for a store whose Pro is too old to have this route.
  ///
  /// **Ordering is enabled here**, deliberately. A 404 means the app cannot
  /// ask, not that the restaurant is shut — and task 8.7's refusal on every
  /// other route is still the floor underneath this. See `FINDINGS.md`.
  static const unknown = StoreConfig(
    name: '',
    logoUrl: '',
    primaryColor: null,
    orderingEnabled: true,
    currency: StoreCurrency.unknown,
  );

  factory StoreConfig.fromJson(Map<String, dynamic> json) {
    final logo = json['logo'];
    final currency = json['currency'];

    return StoreConfig(
      name: json['name'] as String? ?? '',
      logoUrl: logo is Map ? logo['url'] as String? ?? '' : '',
      primaryColor: _colorOf(json['primary_color'] as String?),
      // Absent means an older Pro that cannot say. Taking that as "off" would
      // close a shop over a missing field.
      orderingEnabled: json['ordering_enabled'] as bool? ?? true,
      currency: currency is Map
          ? StoreCurrency.fromJson(currency.cast<String, dynamic>())
          : StoreCurrency.unknown,
      privacyPolicyUrl: json['privacy_policy_url'] as String? ?? '',
      termsUrl: json['terms_url'] as String? ?? '',
    );
  }

  /// The store's own name, for the header. Empty when it has none worth
  /// showing, and the app falls back to the branch.
  final String name;

  /// Empty when the store set no logo. The app keeps its own mark rather than
  /// drawing a gap.
  final String logoUrl;

  /// The store's brand colour, or null to keep the app's own.
  ///
  /// Null for a malformed value as well as a missing one: this reaches a
  /// theme, and a colour that will not parse is a screen nobody can read.
  final Color? primaryColor;

  /// Whether this store is in WooCommerce mode at all (task 8.7).
  final bool orderingEnabled;

  /// How the store writes money, for the screens that must say a price before
  /// a cart or a product has been fetched.
  final StoreCurrency currency;

  /// The store's published privacy policy (task 14.4).
  ///
  /// **Empty is the common case on a fresh store**, because WordPress creates
  /// that page as a draft and `get_privacy_policy_url()` reports nothing until
  /// it is published. The app shows no row rather than a link to a 404 — and
  /// a store that means to ship this app has to publish one, because both
  /// consoles require it.
  final String privacyPolicyUrl;

  /// The store's terms, when WooCommerce has a published page for them.
  /// Optional, and usually empty.
  final String termsUrl;

  /// `#rrggbb` or `#rgb`, and nothing else.
  static Color? _colorOf(String? raw) {
    final value = raw?.trim() ?? '';
    if (!value.startsWith('#')) return null;

    final digits = value.substring(1);
    final expanded = switch (digits.length) {
      3 => digits.split('').map((c) => '$c$c').join(),
      6 => digits,
      _ => null,
    };
    if (expanded == null) return null;

    final parsed = int.tryParse(expanded, radix: 16);

    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}

/// The store's money format.
class StoreCurrency {
  const StoreCurrency({
    required this.code,
    required this.symbol,
    required this.position,
    required this.decimals,
    required this.decimalSeparator,
    required this.thousandSeparator,
  });

  static const unknown = StoreCurrency(
    code: '',
    symbol: '',
    position: 'left',
    decimals: 2,
    decimalSeparator: '.',
    thousandSeparator: ',',
  );

  factory StoreCurrency.fromJson(Map<String, dynamic> json) {
    return StoreCurrency(
      code: json['code'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      position: json['position'] as String? ?? 'left',
      // **Not always 2.** CFA and XOF use none, and a hard-coded two would
      // invent centimes a store does not have.
      decimals: (json['decimals'] as num?)?.toInt() ?? 2,
      decimalSeparator: json['decimal_separator'] as String? ?? '.',
      thousandSeparator: json['thousand_separator'] as String? ?? ',',
    );
  }

  final String code;
  final String symbol;
  final String position;
  final int decimals;
  final String decimalSeparator;
  final String thousandSeparator;
}

/// How one site formats money, as the Store API reports it.
///
/// Every price block in the Store API repeats this metadata — products, cart
/// totals and line totals each carry their own copy — so it is parsed from
/// whichever block is at hand rather than being fetched once and assumed.
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.minorUnit,
    required this.decimalSeparator,
    required this.thousandSeparator,
    required this.prefix,
    required this.suffix,
  });

  /// A sane fallback for tests and for the rare payload with no currency
  /// block. Never used to *reinterpret* an amount — only to render one.
  static const fallback = Currency(
    code: 'USD',
    symbol: r'$',
    minorUnit: 2,
    decimalSeparator: '.',
    thousandSeparator: ',',
    prefix: r'$',
    suffix: '',
  );

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['currency_code'] as String? ?? fallback.code,
      symbol: json['currency_symbol'] as String? ?? fallback.symbol,
      // The exponent that turns minor units into major ones. 2 for USD, but
      // 0 for JPY and 3 for KWD, so it is never assumed.
      minorUnit: (json['currency_minor_unit'] as num?)?.toInt() ??
          fallback.minorUnit,
      decimalSeparator: json['currency_decimal_separator'] as String? ??
          fallback.decimalSeparator,
      thousandSeparator: json['currency_thousand_separator'] as String? ??
          fallback.thousandSeparator,
      prefix: json['currency_prefix'] as String? ?? '',
      suffix: json['currency_suffix'] as String? ?? '',
    );
  }

  final String code;
  final String symbol;

  /// Number of decimal places this currency uses.
  final int minorUnit;
  final String decimalSeparator;
  final String thousandSeparator;

  /// Text before the amount, e.g. `$`. Can be empty.
  final String prefix;

  /// Text after the amount, e.g. ` kr`. Can be empty.
  final String suffix;

  @override
  bool operator ==(Object other) =>
      other is Currency &&
      other.code == code &&
      other.symbol == symbol &&
      other.minorUnit == minorUnit &&
      other.decimalSeparator == decimalSeparator &&
      other.thousandSeparator == thousandSeparator &&
      other.prefix == prefix &&
      other.suffix == suffix;

  @override
  int get hashCode => Object.hash(code, symbol, minorUnit, decimalSeparator,
      thousandSeparator, prefix, suffix);

  @override
  String toString() => 'Currency($code, minorUnit: $minorUnit)';
}

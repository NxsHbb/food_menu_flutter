import 'currency.dart';

/// An amount of money, held in **minor units**.
///
/// This exists because of one Store API trap: prices arrive as *strings in
/// minor units*, alongside a `currency_minor_unit` exponent. `"395"` with
/// exponent 2 is **$3.95**, not $395. Parsing those strings as a decimal — or
/// as a double — is the single easiest way to ship a menu with prices a
/// hundred times too high.
///
/// Amounts stay integers end to end. Doubles are never used for money, so
/// totals cannot drift by a cent.
class Money implements Comparable<Money> {
  const Money({required this.minorUnits, required this.currency});

  /// Zero in the given currency.
  const Money.zero(this.currency) : minorUnits = 0;

  /// Reads a Store API amount string, e.g. `"790"`.
  ///
  /// Returns null when the field is absent or unparseable, which the API does
  /// use in practice — `total_shipping` is null until shipping is calculated.
  static Money? tryParse(Object? raw, Currency currency) {
    if (raw == null) return null;
    if (raw is num) {
      return Money(minorUnits: raw.round(), currency: currency);
    }
    if (raw is! String || raw.isEmpty) return null;
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return null;
    return Money(minorUnits: parsed, currency: currency);
  }

  /// Like [tryParse], but falls back to zero rather than null. For fields the
  /// API always sends, such as `total_price`.
  static Money parseOrZero(Object? raw, Currency currency) =>
      tryParse(raw, currency) ?? Money.zero(currency);

  /// The amount, in the currency's smallest unit (cents, fils, yen).
  final int minorUnits;
  final Currency currency;

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  /// The amount in major units. For display maths only — never for
  /// accumulating totals, which is what [minorUnits] is for.
  double get asDouble => minorUnits / _divisor;

  int get _divisor {
    var divisor = 1;
    for (var i = 0; i < currency.minorUnit; i++) {
      divisor *= 10;
    }
    return divisor;
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currency: currency,
    );
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits - other.minorUnits,
      currency: currency,
    );
  }

  Money operator *(int factor) =>
      Money(minorUnits: minorUnits * factor, currency: currency);

  void _assertSameCurrency(Money other) {
    assert(
      other.currency.code == currency.code,
      'Cannot combine ${currency.code} with ${other.currency.code}.',
    );
  }

  /// Formats using the site's own separators, prefix and suffix, so a store
  /// configured for `1.234,56 kr` renders that way without the app knowing
  /// anything about locales.
  String format() {
    final negative = minorUnits < 0;
    final digits = minorUnits.abs().toString().padLeft(
          currency.minorUnit + 1,
          '0',
        );

    final cut = digits.length - currency.minorUnit;
    final whole = digits.substring(0, cut);
    final fraction = currency.minorUnit == 0 ? '' : digits.substring(cut);

    final grouped = _group(whole);
    final amount = fraction.isEmpty
        ? grouped
        : '$grouped${currency.decimalSeparator}$fraction';

    final prefix = currency.prefix;
    final suffix = currency.suffix;
    return '${negative ? '-' : ''}$prefix$amount$suffix';
  }

  String _group(String whole) {
    if (currency.thousandSeparator.isEmpty || whole.length <= 3) return whole;
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i != 0 && (whole.length - i) % 3 == 0) {
        buffer.write(currency.thousandSeparator);
      }
      buffer.write(whole[i]);
    }
    return buffer.toString();
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency.code == currency.code;

  @override
  int get hashCode => Object.hash(minorUnits, currency.code);

  @override
  String toString() => 'Money(${format()})';
}

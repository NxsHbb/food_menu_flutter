import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/currency.dart';
import 'package:food_menu/src/core/store_api/models/money.dart';

void main() {
  const usd = Currency.fallback;

  group('parsing', () {
    test('reads a minor-unit string as the right amount', () {
      // The trap this whole type exists for: "395" is $3.95, not $395.
      final money = Money.tryParse('395', usd)!;

      expect(money.minorUnits, 395);
      expect(money.format(), r'$3.95');
      expect(money.asDouble, closeTo(3.95, 0.0001));
    });

    test('returns null for absent values', () {
      // total_shipping is null until shipping is calculated.
      expect(Money.tryParse(null, usd), isNull);
      expect(Money.tryParse('', usd), isNull);
      expect(Money.tryParse('not a number', usd), isNull);
    });

    test('parseOrZero falls back for fields that are always sent', () {
      expect(Money.parseOrZero(null, usd).isZero, isTrue);
    });

    test('accepts a numeric amount as well as a string', () {
      expect(Money.tryParse(790, usd)!.minorUnits, 790);
    });
  });

  group('formatting', () {
    test('uses the site separators, prefix and suffix', () {
      const krone = Currency(
        code: 'DKK',
        symbol: 'kr',
        minorUnit: 2,
        decimalSeparator: ',',
        thousandSeparator: '.',
        prefix: '',
        suffix: ' kr',
      );

      expect(Money(minorUnits: 123456, currency: krone).format(), '1.234,56 kr');
    });

    test('handles a zero-decimal currency', () {
      const yen = Currency(
        code: 'JPY',
        symbol: '¥',
        minorUnit: 0,
        decimalSeparator: '.',
        thousandSeparator: ',',
        prefix: '¥',
        suffix: '',
      );

      expect(Money(minorUnits: 1200, currency: yen).format(), '¥1,200');
    });

    test('handles a three-decimal currency', () {
      const dinar = Currency(
        code: 'KWD',
        symbol: 'KD',
        minorUnit: 3,
        decimalSeparator: '.',
        thousandSeparator: ',',
        prefix: 'KD ',
        suffix: '',
      );

      expect(Money(minorUnits: 1234, currency: dinar).format(), 'KD 1.234');
    });

    test('pads amounts smaller than one major unit', () {
      expect(Money(minorUnits: 5, currency: usd).format(), r'$0.05');
      expect(Money(minorUnits: 0, currency: usd).format(), r'$0.00');
    });

    test('groups thousands', () {
      expect(Money(minorUnits: 100000, currency: usd).format(), r'$1,000.00');
      expect(
        Money(minorUnits: 123456789, currency: usd).format(),
        r'$1,234,567.89',
      );
    });

    test('renders negatives with the sign outside the prefix', () {
      expect(Money(minorUnits: -250, currency: usd).format(), r'-$2.50');
    });
  });

  group('arithmetic', () {
    test('adds and subtracts without drift', () {
      final a = Money(minorUnits: 395, currency: usd);
      final b = Money(minorUnits: 1050, currency: usd);

      expect((a + b).minorUnits, 1445);
      expect((b - a).minorUnits, 655);
    });

    test('multiplies by a quantity', () {
      final line = Money(minorUnits: 395, currency: usd) * 3;

      expect(line.minorUnits, 1185);
      expect(line.format(), r'$11.85');
    });

    test('a hundred additions of one cent make exactly one unit', () {
      // The reason amounts are ints: the same loop in doubles does not land
      // on 1.00.
      var total = Money.zero(usd);
      for (var i = 0; i < 100; i++) {
        total += Money(minorUnits: 1, currency: usd);
      }

      expect(total.minorUnits, 100);
      expect(total.format(), r'$1.00');
    });

    test('compares and sorts', () {
      final cheap = Money(minorUnits: 325, currency: usd);
      final dear = Money(minorUnits: 1750, currency: usd);

      expect(cheap.compareTo(dear), isNegative);
      expect([dear, cheap]..sort(), [cheap, dear]);
    });
  });
}

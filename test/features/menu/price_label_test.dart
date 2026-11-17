import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/capability/capability_probe.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_row.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/price_label_text.dart';

import '../../core/capability/capability_scope.dart';
import 'fake_menu_repository.dart';

void main() {
  const label = 'Small 5.95 | Large 6.50';

  group('the model', () {
    test('reads the label the plugin sent', () {
      final product = buildProduct(priceLabel: label);

      expect(product.priceLabel, label);
      expect(product.hasPriceLabel, isTrue);
    });

    test('a dish without one has none', () {
      expect(buildProduct().priceLabel, isEmpty);
      expect(buildProduct().hasPriceLabel, isFalse);
    });

    test('an older plugin, sending no extension at all, has none', () {
      // Absence at every level is "no label", never an error: a site on an
      // older Pro simply does not send the field.
      final product = Product.fromJson(const {
        'id': 1,
        'name': 'Garlic Bread',
        'prices': {
          'price': '450',
          'regular_price': '450',
          'currency_code': 'USD',
          'currency_minor_unit': 2,
          'currency_prefix': r'$',
          'currency_decimal_separator': '.',
          'currency_thousand_separator': ',',
        },
      });

      expect(product.hasPriceLabel, isFalse);
    });

    test('whitespace is not a label', () {
      // A store that typed a space into the box did not mean to replace the
      // price with nothing.
      expect(buildProduct(priceLabel: '   ').hasPriceLabel, isFalse);
    });

    test('the real prices are untouched', () {
      // **Display only.** Every sum in the app still uses these; the label
      // replaces what the customer reads, never what they are charged.
      final product = buildProduct(priceLabel: label, price: '450');

      expect(product.prices.price.format(), r'$4.50');
    });
  });

  group('where a price would be', () {
    Widget wrap(Widget child) => ProviderScope(
          // The dish card carries a wishlist heart, which asks what this
          // store can do (task 14.7). Pinned so the test makes no request.
          overrides: [capabilitiesProvider.overrideWithValue(anyStore)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: SizedBox(width: 390, child: child)),
          ),
        );

    testWidgets('a dish card shows the label instead of the price',
        (tester) async {
      await tester.pumpWidget(
        wrap(DishCard(
          product: buildProduct(priceLabel: label, price: '450'),
          onTap: () {},
        )),
      );

      expect(find.text(label), findsOne);
      expect(find.text(r'$4.50'), findsNothing);
    });

    testWidgets('a dish row shows it too, and drops the options hint',
        (tester) async {
      // A label already says what the choices cost, so the hint would be a
      // second answer to the same question.
      await tester.pumpWidget(
        wrap(
          DishRow(
            product: buildProduct(
              priceLabel: label,
              price: '450',
              hasOptions: true,
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.text(label), findsOne);
      expect(find.text('options'), findsNothing);
    });

    testWidgets('a dish without a label is unchanged', (tester) async {
      await tester.pumpWidget(
        wrap(DishCard(product: buildProduct(price: '450'), onTap: () {})),
      );

      expect(find.byType(PriceLabelText), findsNothing);
      expect(find.text(r'$4.50'), findsOne);
    });

    testWidgets('a long label does not overflow a phone-width card',
        (tester) async {
      // Longer than any price, on the narrowest surface that draws one.
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 170,
            child: DishCard(
              product: buildProduct(
                priceLabel:
                    'Small 5.95 | Medium 7.95 | Large 9.95 | Sharing 14.95',
              ),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

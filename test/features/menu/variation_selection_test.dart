import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';
import 'package:food_menu/src/features/menu/domain/variation_selection.dart';

Product _variableProduct() {
  final json = jsonDecode(
    File('test/fixtures/product_variable.json').readAsStringSync(),
  );
  return Product.fromJson(json as Map<String, dynamic>);
}

void main() {
  late Product pizza;

  setUp(() => pizza = _variableProduct());

  group('the Store API payload', () {
    test('reads the attribute, its terms and every variation', () {
      expect(pizza.type, 'variable');
      expect(pizza.variableAttributes, hasLength(1));

      final size = pizza.variableAttributes.single;
      expect(size.name, 'Size');
      // A custom attribute, which is what a restaurant types in rather than
      // registering as a taxonomy.
      expect(size.taxonomy, isEmpty);
      expect(size.terms.map((t) => t.slug), ['Small', 'Medium', 'Large']);
      expect(pizza.variations, hasLength(3));
    });

    test('a descriptive attribute is not a question', () {
      final product = Product.fromJson({
        'id': 1,
        'attributes': [
          {
            'name': 'Allergens',
            'has_variations': false,
            'terms': [
              {'name': 'Gluten', 'slug': 'gluten'},
            ],
          },
        ],
      });

      expect(product.attributes, hasLength(1));
      // Only attributes that pick a variation are drawn.
      expect(product.variableAttributes, isEmpty);
    });
  });

  group('VariationSelection', () {
    test('resolves a complete choice to the right variation', () {
      final size = pizza.variableAttributes.single;
      final selection = const VariationSelection().choose(size.name, 'Medium');

      expect(selection.isComplete(pizza.variableAttributes), isTrue);
      expect(selection.resolve(pizza)?.id, 29);
    });

    test('resolves nothing until every attribute is answered', () {
      expect(const VariationSelection().resolve(pizza), isNull);
      expect(
        const VariationSelection().unanswered(pizza.variableAttributes),
        hasLength(1),
      );
    });

    test('a combination the store never made resolves to nothing', () {
      final size = pizza.variableAttributes.single;
      final selection =
          const VariationSelection().choose(size.name, 'Gigantic');

      // Complete, and still no match — which the screen says out loud rather
      // than letting the server answer "no such variation".
      expect(selection.isComplete(pizza.variableAttributes), isTrue);
      expect(selection.resolve(pizza), isNull);
    });

    test('choosing again replaces, it does not accumulate', () {
      final size = pizza.variableAttributes.single;
      final selection = const VariationSelection()
          .choose(size.name, 'Small')
          .choose(size.name, 'Large');

      expect(selection.chosen, {'Size': 'Large'});
      expect(selection.resolve(pizza)?.id, 30);
    });

    test('an empty attribute value on a variation means any', () {
      // WooCommerce's "any size" variation. Matching it literally would make
      // it match nothing at all.
      final product = Product.fromJson({
        'id': 1,
        'attributes': [
          {
            'name': 'Size',
            'has_variations': true,
            'terms': [
              {'name': 'Small', 'slug': 'Small'},
            ],
          },
        ],
        'variations': [
          {
            'id': 99,
            'attributes': [
              {'name': 'Size', 'value': null},
            ],
          },
        ],
      });

      final selection = const VariationSelection().choose('Size', 'Small');
      expect(selection.resolve(product)?.id, 99);
    });

    test('builds exactly what cart/add-item takes', () {
      final size = pizza.variableAttributes.single;
      final selection = const VariationSelection().choose(size.name, 'Large');

      // The attribute's own name goes out verbatim — the Store API sanitises
      // it to the variation's meta key, so Size and size both resolve.
      expect(selection.toPayload(pizza.variableAttributes), [
        {'attribute': 'Size', 'value': 'Large'},
      ]);
    });

    test('an unanswered attribute contributes nothing to the payload', () {
      expect(
        const VariationSelection().toPayload(pizza.variableAttributes),
        isEmpty,
      );
    });
  });

  group('a simple dish', () {
    test('has no attributes to answer and resolves to nothing', () {
      final json = jsonDecode(
        File('test/fixtures/product_simple.json').readAsStringSync(),
      );
      final simple = Product.fromJson(json as Map<String, dynamic>);

      expect(simple.variableAttributes, isEmpty);
      expect(const VariationSelection().isComplete(simple.variableAttributes),
          isTrue);
      expect(const VariationSelection().resolve(simple), isNull);
    });
  });
}

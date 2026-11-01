import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/menu/domain/category_suggestions.dart';

import 'fake_menu_repository.dart';

void main() {
  // The categories actually seeded on the dev site.
  final categories = [
    buildCategory(id: 1, name: 'Burgers', count: 3),
    buildCategory(id: 2, name: 'Desserts', count: 2),
    buildCategory(id: 3, name: 'Drinks', count: 2),
    buildCategory(id: 4, name: 'Main Course', count: 3),
    buildCategory(id: 5, name: 'Pizza', count: 4),
    buildCategory(id: 6, name: 'Starters', count: 3),
  ];

  List<String> namesFor(String query) =>
      suggestCategories(categories, query).map((c) => c.name).toList();

  test('the motivating case: "pizza" finds Pizza', () {
    // WooCommerce search returns nothing for this, because no product is
    // named "pizza".
    expect(namesFor('pizza'), ['Pizza']);
  });

  test('matches regardless of case', () {
    expect(namesFor('PIZZA'), ['Pizza']);
    expect(namesFor('  Pizza '), ['Pizza']);
  });

  test('singular query finds a plural category', () {
    expect(namesFor('burger'), ['Burgers']);
    expect(namesFor('dessert'), ['Desserts']);
    expect(namesFor('starter'), ['Starters']);
  });

  test('plural query finds a singular category', () {
    expect(namesFor('pizzas'), ['Pizza']);
  });

  test('matches a whole word inside a longer name', () {
    expect(namesFor('course'), ['Main Course']);
    expect(namesFor('main'), ['Main Course']);
  });

  test('ranks an exact match above a partial one', () {
    final withOverlap = [
      buildCategory(id: 7, name: 'Drinks & Smoothies'),
      buildCategory(id: 8, name: 'Drinks'),
    ];

    expect(
      suggestCategories(withOverlap, 'drinks').first.name,
      'Drinks',
    );
  });

  test('does not guess at synonyms', () {
    // Relating words is useful; inventing cuisine knowledge is not.
    expect(namesFor('italian'), isEmpty);
    expect(namesFor('vegan'), isEmpty);
  });

  test('ignores a query too short to be meaningful', () {
    expect(namesFor('p'), isEmpty);
    expect(namesFor(''), isEmpty);
    expect(namesFor(' '), isEmpty);
  });

  test('a short query does not match on substring alone', () {
    // "ink" inside "Drinks" is coincidence, not intent.
    expect(namesFor('ink'), isEmpty);
  });

  test('a substring match needs at least four characters', () {
    // Three is coincidence ("ink" in Drinks); four or more is usually intent.
    expect(namesFor('ink'), isEmpty);
    expect(namesFor('sert'), ['Desserts']);
    expect(namesFor('esserts'), ['Desserts']);
  });

  test('caps the number of suggestions', () {
    final many = [
      for (var i = 0; i < 10; i++) buildCategory(id: i, name: 'Drinks $i'),
    ];

    expect(suggestCategories(many, 'drinks'), hasLength(3));
    expect(suggestCategories(many, 'drinks', limit: 5), hasLength(5));
  });

  test('no categories means no suggestions', () {
    expect(suggestCategories(const [], 'pizza'), isEmpty);
  });
}

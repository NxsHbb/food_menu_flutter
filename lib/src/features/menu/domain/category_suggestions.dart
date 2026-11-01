import '../../../core/store_api/models/menu_category.dart';

/// Finds categories whose name relates to a search term.
///
/// Exists because WooCommerce's product search matches **product names only**.
/// A customer typing a cuisine — "pizza", "dessert" — gets an empty list even
/// when a category of exactly that name is full of dishes. Rather than widen
/// the server query, the app offers the category as a way out of the dead end.
///
/// Matching is deliberately forgiving in one direction only: it relates words,
/// it does not guess at synonyms. "pizza" finds Pizza, "burger" finds Burgers,
/// "pizzas" finds Pizza. "italian" does not find Pizza, and should not.
List<MenuCategory> suggestCategories(
  List<MenuCategory> categories,
  String query, {
  int limit = 3,
}) {
  final needle = _normalise(query);
  if (needle.length < 2) return const [];

  final scored = <({MenuCategory category, int rank})>[];

  for (final category in categories) {
    final name = _normalise(category.name);
    if (name.isEmpty) continue;

    final rank = _rank(name, needle);
    if (rank == null) continue;
    scored.add((category: category, rank: rank));
  }

  // Best match first; equal ranks keep the server's ordering.
  scored.sort((a, b) => a.rank.compareTo(b.rank));

  return scored.take(limit).map((e) => e.category).toList(growable: false);
}

/// Lower is a better match. Null means no match at all.
int? _rank(String name, String needle) {
  if (name == needle) return 0;

  // Singular/plural, both ways: "burger" vs Burgers, "pizzas" vs Pizza.
  if (_depluralise(name) == _depluralise(needle)) return 1;

  if (name.startsWith(needle)) return 2;
  if (_depluralise(name).startsWith(_depluralise(needle))) return 3;

  // A whole-word hit inside a longer name: "course" in Main Course.
  if (name.split(' ').any((word) => _depluralise(word) == _depluralise(needle))) {
    return 4;
  }

  // Last resort, and only when the term is substantial enough that a
  // substring hit is likely to be meaningful rather than coincidental.
  if (needle.length >= 4 && name.contains(needle)) return 5;

  return null;
}

String _normalise(String value) => value.trim().toLowerCase();

/// Naive singularisation. Enough for category labels, which are short nouns;
/// not a general stemmer, and deliberately not one.
String _depluralise(String value) {
  if (value.endsWith('ies') && value.length > 4) {
    return '${value.substring(0, value.length - 3)}y';
  }
  if (value.endsWith('ses') && value.length > 4) {
    return value.substring(0, value.length - 2);
  }
  if (value.endsWith('s') && !value.endsWith('ss') && value.length > 3) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

import '../../../core/store_api/models/product.dart';

/// Which term is chosen for each of a variable dish's attributes.
///
/// A variable dish — the design's "small / medium / large in one item" — is a
/// parent product plus a variation per combination. The customer picks a term
/// per attribute; the matching variation is what actually goes in the cart.
///
/// **Matched on names and values, not ids.** A *custom* product attribute, the
/// kind a restaurant types in rather than registering as a taxonomy, comes
/// back from the Store API with `id: 0` on both the attribute and every term,
/// and `taxonomy: null`. Only `name` and `slug` identify it. A taxonomy
/// attribute has real ids, but its `slug` is just as unique — so matching on
/// the strings is the one rule that works for both.
class VariationSelection {
  const VariationSelection([this.chosen = const {}]);

  /// Attribute name to the chosen term's slug.
  final Map<String, String> chosen;

  /// Everything already answered, with [name] now set to [slug].
  VariationSelection choose(String name, String slug) {
    return VariationSelection({...chosen, name: slug});
  }

  String? slugFor(ProductAttribute attribute) => chosen[attribute.name];

  bool isChosen(ProductAttribute attribute, AttributeTerm term) =>
      chosen[attribute.name] == term.slug;

  /// The attributes still without an answer, in the order they are drawn.
  List<ProductAttribute> unanswered(List<ProductAttribute> attributes) {
    return [
      for (final attribute in attributes)
        if (!chosen.containsKey(attribute.name)) attribute,
    ];
  }

  bool isComplete(List<ProductAttribute> attributes) =>
      unanswered(attributes).isEmpty;

  /// The variation this selection names, or null while it names none.
  ///
  /// Null covers three different things on purpose, because the screen treats
  /// them the same: not finished choosing, a combination the store never made,
  /// and a dish with no variations at all.
  ProductVariation? resolve(Product product) {
    if (!isComplete(product.variableAttributes)) return null;

    for (final variation in product.variations) {
      if (_matches(variation)) return variation;
    }

    return null;
  }

  bool _matches(ProductVariation variation) {
    for (final entry in variation.attributes.entries) {
      // An **empty value means "any"** in WooCommerce: a variation that leaves
      // one attribute blank serves every term of it. Rare, and silently wrong
      // if treated as a literal empty string to match against.
      if (entry.value.isEmpty) continue;

      if (chosen[entry.key] != entry.value) return false;
    }

    return true;
  }

  /// What `cart/add-item` takes.
  ///
  /// The attribute's own name goes out verbatim — the Store API sanitises it
  /// to the variation's meta key itself, so both `Size` and `size` resolve to
  /// `attribute_size`. Sending what the payload gave us keeps one fewer rule
  /// in this app.
  List<Map<String, Object>> toPayload(List<ProductAttribute> attributes) {
    return [
      for (final attribute in attributes)
        if (chosen[attribute.name] case final slug?)
          {'attribute': attribute.name, 'value': slug},
    ];
  }
}

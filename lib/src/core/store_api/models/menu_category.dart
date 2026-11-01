/// A category from `wc/store/v1/products/categories`.
///
/// Richer than the [ProductCategory] the API embeds on a product: this one
/// carries the item count, an optional image and the parent id, which the
/// embedded form omits.
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    required this.parent,
    this.imageUrl,
    this.description = '',
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    return MenuCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      // Number of published products in the category.
      count: (json['count'] as num?)?.toInt() ?? 0,
      parent: (json['parent'] as num?)?.toInt() ?? 0,
      imageUrl: image is Map ? image['src'] as String? : null,
      description: json['description'] as String? ?? '',
    );
  }

  final int id;
  final String name;
  final String slug;
  final int count;

  /// 0 for a top-level category.
  final int parent;
  final String? imageUrl;
  final String description;

  bool get isTopLevel => parent == 0;

  /// Categories with nothing in them are hidden rather than shown empty.
  bool get hasItems => count > 0;

  @override
  String toString() => 'MenuCategory($id, $name, $count items)';
}

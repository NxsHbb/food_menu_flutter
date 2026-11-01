import 'package:food_menu/src/core/store_api/models/menu_category.dart';
import 'package:food_menu/src/core/store_api/models/product.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';

/// A [MenuRepository] that answers from memory, so widget tests never touch
/// the network.
class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository({
    this.categoryList = const [],
    this.productList = const [],
    this.categoriesError,
    this.productsError,
    this.delay = Duration.zero,
  });

  final List<MenuCategory> categoryList;
  final List<Product> productList;
  final Object? categoriesError;
  final Object? productsError;
  final Duration delay;

  /// Category ids the screen asked for, in order.
  final List<int?> requestedCategories = [];

  @override
  Future<List<MenuCategory>> categories() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (categoriesError != null) throw categoriesError!;
    return categoryList;
  }

  @override
  Future<List<Product>> products({
    int? categoryId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    requestedCategories.add(categoryId);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (productsError != null) throw productsError!;
    if (categoryId == null) return productList;
    return productList
        .where((p) => p.categories.any((c) => c.id == categoryId))
        .toList();
  }
}

/// Builds a product without writing out a whole Store API payload.
Product buildProduct({
  int id = 1,
  String name = 'Margherita',
  String price = '900',
  String? regularPrice,
  int reviewCount = 0,
  String rating = '0',
  bool hasOptions = false,
  bool inStock = true,
  List<Map<String, dynamic>> categories = const [],
}) {
  return Product.fromJson({
    'id': id,
    'name': name,
    'type': hasOptions ? 'variable' : 'simple',
    'prices': {
      'price': price,
      'regular_price': regularPrice ?? price,
      'sale_price': price,
      'currency_code': 'USD',
      'currency_minor_unit': 2,
      'currency_prefix': r'$',
      'currency_decimal_separator': '.',
      'currency_thousand_separator': ',',
    },
    'categories': categories,
    'images': const <dynamic>[],
    'is_in_stock': inStock,
    'is_purchasable': true,
    'has_options': hasOptions,
    'review_count': reviewCount,
    'average_rating': rating,
  });
}

MenuCategory buildCategory({
  int id = 10,
  String name = 'Pizza',
  int count = 3,
}) {
  return MenuCategory.fromJson({
    'id': id,
    'name': name,
    'slug': name.toLowerCase(),
    'count': count,
    'parent': 0,
  });
}

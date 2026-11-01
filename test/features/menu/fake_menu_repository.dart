export 'package:food_menu/src/core/store_api/models/product.dart';

import 'package:food_menu/src/core/network/paged.dart';
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
  Object? productsError;
  final Duration delay;

  /// Category ids the screen asked for, in order.
  final List<int?> requestedCategories = [];

  @override
  Future<List<MenuCategory>> categories() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (categoriesError != null) throw categoriesError!;
    return categoryList;
  }

  /// Returned by [product]; falls back to the first item in [productList].
  Product? single;

  /// Thrown by [product] when set.
  Object? productError;

  @override
  Future<Product> product(int id) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (productError != null) throw productError!;
    final match = single ??
        productList.where((p) => p.id == id).firstOrNull ??
        productList.firstOrNull;
    if (match == null) throw StateError('no product configured for id $id');
    return match;
  }

  /// Every page request the controller made, as (categoryId, search, page).
  final List<({int? categoryId, String? search, int page})> pageRequests = [];

  /// Products per page, so pagination can be exercised with a short list.
  int pageSize = 20;

  @override
  Future<Paged<Product>> productPage({
    int? categoryId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    pageRequests.add((categoryId: categoryId, search: search, page: page));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (productsError != null) throw productsError!;

    var matches = productList;
    if (categoryId != null) {
      matches = matches
          .where((p) => p.categories.any((c) => c.id == categoryId))
          .toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final needle = search.trim().toLowerCase();
      matches =
          matches.where((p) => p.name.toLowerCase().contains(needle)).toList();
    }

    final start = (page - 1) * pageSize;
    final slice = start >= matches.length
        ? <Product>[]
        : matches.sublist(
            start,
            (start + pageSize).clamp(0, matches.length),
          );
    final totalPages = matches.isEmpty
        ? 0
        : ((matches.length - 1) ~/ pageSize) + 1;

    return Paged(
      items: slice,
      total: matches.length,
      totalPages: totalPages,
      page: page,
    );
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

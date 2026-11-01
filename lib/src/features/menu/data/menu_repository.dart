import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paged.dart';
import '../../../core/store_api/models/menu_category.dart';
import '../../../core/store_api/models/product.dart';

/// Reads the menu from the WooCommerce Store API.
///
/// Both endpoints used here are public — no nonce, no token — so the menu
/// loads before a customer signs in.
class MenuRepository {
  const MenuRepository(this._client);

  final ApiClient _client;

  /// Categories that have at least one dish in them, top-level first.
  ///
  /// Empty categories are filtered out here rather than in the UI: an empty
  /// chip that leads to an empty list is never useful, and the count is only
  /// available at this layer.
  Future<List<MenuCategory>> categories() async {
    final raw = await _client.get<List<dynamic>>(
      _client.storeApi('products/categories'),
      query: const {'per_page': 100, 'hide_empty': true, 'orderby': 'name'},
    );

    return raw
        .whereType<Map>()
        .map((e) => MenuCategory.fromJson(e.cast<String, dynamic>()))
        .where((c) => c.hasItems)
        .toList(growable: false);
  }

  /// One dish by id, for the detail screen.
  Future<Product> product(int id) async {
    final raw = await _client.get<Map<String, dynamic>>(
      _client.storeApi('products/$id'),
    );
    return Product.fromJson(raw);
  }

  /// A page of dishes with its totals, for the paginated list screen.
  Future<Paged<Product>> productPage({
    int? categoryId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final raw = await _client.getPaged(
      _client.storeApi('products'),
      page: page,
      query: {
        'per_page': perPage,
        'catalog_visibility': 'catalog',
        'category': ?categoryId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    return Paged(
      items: raw.items.map(Product.fromJson).toList(growable: false),
      total: raw.total,
      totalPages: raw.totalPages,
      page: raw.page,
    );
  }

  /// A page of dishes, optionally narrowed to one category or a search term.
  Future<List<Product>> products({
    int? categoryId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final raw = await _client.get<List<dynamic>>(
      _client.storeApi('products'),
      query: {
        'page': page,
        'per_page': perPage,
        // Hide anything the customer cannot order, so the menu never shows a
        // dish that fails at add-to-cart.
        'catalog_visibility': 'catalog',
        'category': ?categoryId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    return raw
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(apiClientProvider));
});

/// The category chips on the menu landing screen.
final menuCategoriesProvider = FutureProvider<List<MenuCategory>>((ref) {
  return ref.watch(menuRepositoryProvider).categories();
});

/// Which category is selected, or null for "all".
class SelectedCategory extends Notifier<int?> {
  @override
  int? build() => null;

  /// Selects a category, or clears the filter when the selected chip is
  /// tapped again.
  void toggle(int id) => state = state == id ? null : id;

  void clear() => state = null;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategory, int?>(SelectedCategory.new);

/// One dish, by id. Keyed so navigating between dishes does not refetch one
/// already loaded in this session.
final productProvider = FutureProvider.family<Product, int>((ref, id) {
  return ref.watch(menuRepositoryProvider).product(id);
});

/// The dishes shown for the current selection.
final menuProductsProvider = FutureProvider<List<Product>>((ref) {
  final categoryId = ref.watch(selectedCategoryProvider);
  return ref.watch(menuRepositoryProvider).products(categoryId: categoryId);
});

export 'package:food_menu/src/features/menu/domain/product_addons.dart';

import 'dart:convert';
import 'dart:io';

import 'package:food_menu/src/features/menu/data/addons_repository.dart';
import 'package:food_menu/src/features/menu/domain/product_addons.dart';

/// An [AddonsRepository] that answers from memory, so widget tests never
/// touch the network.
class FakeAddonsRepository implements AddonsRepository {
  FakeAddonsRepository({this.addons, this.error});

  /// Returned by [forProduct]. Null with no [error] means a dish with no
  /// add-on groups, which is the common case on a real store.
  ProductAddons? addons;

  /// Thrown by [forProduct] when set — a store whose plugin predates the
  /// route answers 404.
  Object? error;

  /// Product ids asked about, in order.
  final List<int> requested = [];

  @override
  Future<ProductAddons> forProduct(int productId) async {
    requested.add(productId);
    if (error != null) throw error!;
    return addons ?? ProductAddons.none(productId);
  }
}

/// Reads an add-ons payload from `test/fixtures`.
ProductAddons addonsFromFixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return ProductAddons.fromJson(json as Map<String, dynamic>);
}

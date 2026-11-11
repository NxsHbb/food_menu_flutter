import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/config/app_config.dart';
import 'package:food_menu/src/core/network/api_client.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';

import '../../core/network/fake_adapter.dart';

/// One product payload with a timed block, as the Store API sends it.
Map<String, dynamic> timedProduct({
  required int id,
  required String name,
  required bool available,
  required String behavior,
  String note = '',
}) {
  return {
    'id': id,
    'name': name,
    'prices': const {'price': '900', 'currency_minor_unit': 2},
    'extensions': {
      'food-menu-pro': {
        'timed': {
          'available': available,
          'behavior': behavior,
          'note': note,
        },
      },
    },
  };
}

void main() {
  const config = AppConfig(baseUrl: 'https://example.com');

  MenuRepository repositoryReturning(List<Map<String, dynamic>> products) {
    final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
      ..httpClientAdapter = FakeAdapter((_) => FakeResponse(body: products));

    return MenuRepository(ApiClient(dio: dio, config: config));
  }

  group('a store that hides what it is not serving', () {
    test('drops the dish from the menu list', () async {
      final repository = repositoryReturning([
        timedProduct(
          id: 14,
          name: 'Margherita',
          available: false,
          behavior: 'disappear',
        ),
        timedProduct(
          id: 22,
          name: 'Iced Latte',
          available: true,
          behavior: 'disappear',
        ),
      ]);

      final products = await repository.products();

      expect(products.map((p) => p.name), ['Iced Latte']);
    });

    test('keeps a dish the store only wants greyed out', () async {
      final repository = repositoryReturning([
        timedProduct(
          id: 14,
          name: 'Margherita',
          available: false,
          behavior: 'disable',
          note: 'Will be Available: 8:00 am – 11:00 am',
        ),
      ]);

      final products = await repository.products();

      // Drawn, and saying so: the store asked for this one to be seen.
      expect(products, hasLength(1));
      expect(products.single.isOrderable, isFalse);
      expect(
        products.single.unavailableReason,
        'Will be Available: 8:00 am – 11:00 am',
      );
    });
  });
}

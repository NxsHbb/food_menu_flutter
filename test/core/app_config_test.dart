import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('derives the Store API base from the site root', () {
      const config = AppConfig(baseUrl: 'https://example.com');
      expect(config.storeApiBase, 'https://example.com/wp-json/wc/store/v1');
    });

    test('derives the Food Menu API base from the site root', () {
      const config = AppConfig(baseUrl: 'https://example.com');
      expect(config.foodMenuApiBase, 'https://example.com/wp-json/fmp/v1');
    });

    test('reads a usable default from the environment', () {
      final config = AppConfig.fromEnvironment();
      expect(config.baseUrl, isNotEmpty);
      expect(config.baseUrl, anyOf(startsWith('http://'), startsWith('https://')));
      expect(config.baseUrl, isNot(endsWith('/')));
    });
  });
}

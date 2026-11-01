/// Runtime configuration, supplied at build time with `--dart-define`.
///
/// The backend is a WordPress site running the Food Menu plugins, so the base
/// URL changes per environment and must never be hard-coded to a developer's
/// machine. See docs/LOCAL_DEV.md for the local default.
class AppConfig {
  const AppConfig({required this.baseUrl});

  /// Reads configuration from the compile-time environment.
  ///
  /// Pass the backend with:
  /// `flutter run --dart-define=FOOD_MENU_BASE_URL=http://192.168.0.171:8080`
  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment(
      'FOOD_MENU_BASE_URL',
      defaultValue: _localDefault,
    );
    assert(
      url.startsWith('http://') || url.startsWith('https://'),
      'FOOD_MENU_BASE_URL must include a scheme: $url',
    );
    assert(
      !url.endsWith('/'),
      'FOOD_MENU_BASE_URL must not end with a slash: $url',
    );
    return const AppConfig(baseUrl: url);
  }

  /// The local development site. An emulator reaches the host machine at
  /// 10.0.2.2, and a physical device needs the LAN address, so `localhost` is
  /// never a useful default here.
  static const _localDefault = 'http://192.168.0.171:8080';

  /// Site root, without a trailing slash, e.g. `https://example.com`.
  final String baseUrl;

  /// WooCommerce Store API — public menu reads and cart writes.
  String get storeApiBase => '$baseUrl/wp-json/wc/store/v1';

  /// The Food Menu plugin's own namespace, used for everything the Store API
  /// does not cover (add-ons, order types, slots, branches, accounts).
  String get foodMenuApiBase => '$baseUrl/wp-json/fmp/v1';

}

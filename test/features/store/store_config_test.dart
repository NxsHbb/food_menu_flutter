import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/config/app_config.dart';
import 'package:food_menu/src/core/network/api_client.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_palette.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/core/theme/app_tokens.dart';
import 'package:food_menu/src/core/theme/brand_color.dart';
import 'package:food_menu/src/features/store/data/store_config_repository.dart';
import 'package:food_menu/src/features/store/domain/store_config.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_menu/src/features/account/presentation/widgets/account_row.dart';
import 'package:food_menu/src/features/account/presentation/widgets/legal_card.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/menu_header.dart';

import '../../core/network/fake_adapter.dart';

void main() {
  /// WCAG contrast of white against [colour].
  double contrast(Color colour) => 1.05 / (colour.computeLuminance() + 0.05);

  group('the store a payload describes', () {
    test('reads what the server sent', () {
      final config = StoreConfig.fromJson(const {
        'name': 'Food Menu Dev',
        'logo': {'url': 'https://example.com/logo.png'},
        'primary_color': '#1a73e8',
        'ordering_enabled': true,
        'currency': {
          'code': 'USD',
          'symbol': r'$',
          'position': 'left',
          'decimals': 2,
          'decimal_separator': '.',
          'thousand_separator': ',',
        },
      });

      expect(config.name, 'Food Menu Dev');
      expect(config.logoUrl, 'https://example.com/logo.png');
      expect(config.primaryColor, const Color(0xFF1A73E8));
      expect(config.orderingEnabled, isTrue);
      expect(config.currency.code, 'USD');
    });

    test('a store with ordering switched off says so', () {
      final config = StoreConfig.fromJson(const {'ordering_enabled': false});

      expect(config.orderingEnabled, isFalse);
    });

    test('a missing ordering flag is open, not shut', () {
      // An older Pro cannot say. Reading that as "closed" would shut a shop
      // over a field that was never sent.
      expect(StoreConfig.fromJson(const {}).orderingEnabled, isTrue);
    });

    test('a short hex is expanded', () {
      final config = StoreConfig.fromJson(const {'primary_color': '#0a0'});

      expect(config.primaryColor, const Color(0xFF00AA00));
    });

    test('a colour that will not parse is no colour at all', () {
      // This reaches a theme. A half-read colour is a screen nobody can read,
      // so anything doubtful keeps the app's own.
      for (final raw in ['', 'red', '#12', '#12345', 'ffffff', '#gggggg']) {
        expect(
          StoreConfig.fromJson({'primary_color': raw}).primaryColor,
          isNull,
          reason: raw,
        );
      }
    });

    test('a currency with no decimals is kept at none', () {
      // CFA and XOF have none. Defaulting to two invents centimes.
      final config = StoreConfig.fromJson(const {
        'currency': {'code': 'XOF', 'decimals': 0},
      });

      expect(config.currency.decimals, 0);
    });
  });

  group('reading it', () {
    const config = AppConfig(baseUrl: 'https://example.com');

    StoreConfigRepository repoFor(
      FakeResponse Function(RequestOptions options) respond,
    ) {
      final dio = Dio(BaseOptions(baseUrl: config.baseUrl))
        ..httpClientAdapter = FakeAdapter(respond);
      return StoreConfigRepository(ApiClient(dio: dio, config: config));
    }

    test('an older Pro, with no such route, is not a failure', () async {
      // The newest route the app asks for. A 404 means this Pro cannot say,
      // and everything else still works — task 14.7's rule, early.
      final repo = repoFor((_) => const FakeResponse(statusCode: 404));

      final store = await repo.config();

      expect(store.orderingEnabled, isTrue);
      expect(store.primaryColor, isNull);
      expect(store.logoUrl, isEmpty);
    });

    test('a real failure is still a failure', () async {
      // A store that cannot be reached is not a store with no branding, and
      // swallowing this would hide an outage behind a default theme.
      final repo = repoFor((_) => const FakeResponse(statusCode: 500));

      expect(repo.config(), throwsA(isA<ApiException>()));
    });
  });

  group('a brand colour the app can draw on', () {
    test('leaves the app its own red untouched', () {
      // The plugin's default is the app's red, so the common store — which
      // never opens the setting — changes nothing at all.
      expect(BrandColor.resolve(AppTokens.brand), AppTokens.brand);
    });

    test('darkens a pale colour until white can be read on it', () {
      const paleYellow = Color(0xFFFFF176);

      expect(contrast(paleYellow), lessThan(BrandColor.minimumContrast));

      final resolved = BrandColor.resolve(paleYellow);

      expect(
        contrast(resolved),
        greaterThanOrEqualTo(BrandColor.minimumContrast),
      );
    });

    test('keeps the hue it was given', () {
      // The store chose the colour; the app only chose how dark.
      const paleYellow = Color(0xFFFFF176);
      final resolved = HSLColor.fromColor(BrandColor.resolve(paleYellow));

      expect(
        resolved.hue,
        closeTo(HSLColor.fromColor(paleYellow).hue, 1),
      );
    });

    test('every colour it returns can carry white text', () {
      for (final colour in const [
        Color(0xFFFFFFFF),
        Color(0xFFFFF176),
        Color(0xFF00E5FF),
        Color(0xFF000000),
        Color(0xFF7E57C2),
      ]) {
        expect(
          contrast(BrandColor.resolve(colour)),
          greaterThanOrEqualTo(BrandColor.minimumContrast),
          reason: '$colour',
        );
      }
    });

    test('the pressed state is deeper than the brand', () {
      final brand = BrandColor.resolve(const Color(0xFF1A73E8));

      expect(
        BrandColor.pressed(brand).computeLuminance(),
        lessThan(brand.computeLuminance()),
      );
    });
  });

  group('the theme it produces', () {
    test('without a store colour, nothing moves', () {
      expect(
        AppTheme.light().colorScheme.primary,
        AppTheme.light(brand: null).colorScheme.primary,
      );
    });

    test("takes the store's colour into the scheme", () {
      const blue = Color(0xFF1A73E8);
      final theme = AppTheme.light(brand: blue);

      expect(theme.colorScheme.primary, BrandColor.resolve(blue));
    });

    test('moves the wash with it, so two reds never share a screen', () {
      const blue = Color(0xFF1A73E8);
      final palette = AppPalette.light().branded(blue);

      expect(palette.tint, isNot(AppPalette.light().tint));
      expect(palette.brand, BrandColor.resolve(blue));
    });

    test('is the same colour in dark mode', () {
      // The design puts the brand outside the light/dark map, and a store
      // that chose one colour did not choose two.
      const blue = Color(0xFF1A73E8);

      expect(
        AppTheme.dark(brand: blue).colorScheme.primary,
        AppTheme.light(brand: blue).colorScheme.primary,
      );
    });
  });

  group("the store's mark on the header", () {
    Widget headerWith(String logoUrl) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MenuHeader(
            addressLabel: 'Ordering from',
            address: 'Food Menu Dev',
            greeting: 'Welcome',
            prompt: 'What are you craving?',
            onSearchTap: () {},
            logoUrl: logoUrl,
          ),
        ),
      );
    }

    testWidgets('a store with no logo gets no gap where one would be',
        (tester) async {
      await tester.pumpWidget(headerWith(''));

      expect(find.byType(Image), findsNothing);
      expect(find.text('Food Menu Dev'), findsOne);
    });

    testWidgets('a store with one has it drawn', (tester) async {
      await tester.pumpWidget(headerWith('https://example.com/logo.png'));

      expect(find.byType(Image), findsOne);
    });

    testWidgets('a logo that will not load closes the row up', (tester) async {
      // A store can point this at a url that has moved. A broken-image glyph
      // on the first screen is the store's own branding looking broken.
      await tester.pumpWidget(headerWith('https://example.com/gone.png'));

      final image = tester.widget<Image>(find.byType(Image));
      final fallback = image.errorBuilder!(
        tester.element(find.byType(MenuHeader)),
        'nope',
        null,
      );

      expect(fallback, isA<SizedBox>());
      expect(tester.takeException(), isNull);
    });
  });

  group("the store's own pages (task 14.4)", () {
    test('are read when the store published them', () {
      final config = StoreConfig.fromJson(const {
        'privacy_policy_url': 'https://example.com/privacy-policy/',
        'terms_url': 'https://example.com/terms/',
      });

      expect(config.privacyPolicyUrl, 'https://example.com/privacy-policy/');
      expect(config.termsUrl, 'https://example.com/terms/');
    });

    test('are empty when it has not', () {
      // WordPress creates the privacy page as a draft, so this is the common
      // case rather than the edge one.
      final config = StoreConfig.fromJson(const {});

      expect(config.privacyPolicyUrl, isEmpty);
      expect(config.termsUrl, isEmpty);
    });

    Widget accountCardIn(StoreConfig store) {
      return ProviderScope(
        overrides: [storeConfigProvider.overrideWith((ref) async => store)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: LegalCard()),
        ),
      );
    }

    StoreConfig storeWith({String privacy = '', String terms = ''}) =>
        StoreConfig(
          name: 'Food Menu Dev',
          logoUrl: '',
          primaryColor: null,
          orderingEnabled: true,
          currency: StoreCurrency.unknown,
          privacyPolicyUrl: privacy,
          termsUrl: terms,
        );

    testWidgets('a store with a policy gets a row', (tester) async {
      await tester.pumpWidget(
        accountCardIn(storeWith(privacy: 'https://example.com/privacy/')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy policy'), findsOne);
      expect(find.text('Terms & conditions'), findsNothing);
    });

    testWidgets('terms show only when the store has published them',
        (tester) async {
      await tester.pumpWidget(
        accountCardIn(storeWith(
          privacy: 'https://example.com/privacy/',
          terms: 'https://example.com/terms/',
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms & conditions'), findsOne);
    });

    testWidgets('a store with neither draws nothing at all', (tester) async {
      // Not an empty card, and no gap where one would be: this is the common
      // store, so a stray space would show on more screens than the card.
      await tester.pumpWidget(accountCardIn(storeWith()));
      await tester.pumpAndSettle();

      expect(find.byType(AccountRow), findsNothing);
      expect(find.byType(AccountRowCard), findsNothing);
      expect(
        tester.getSize(find.byType(LegalCard)),
        Size.zero,
      );
    });
  });
}

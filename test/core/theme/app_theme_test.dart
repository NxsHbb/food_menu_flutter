import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_palette.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/core/theme/app_tokens.dart';
import 'package:food_menu/src/core/theme/app_typography.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses the design page and brand colours', () {
      final theme = AppTheme.light();

      expect(theme.colorScheme.primary, AppTokens.brand);
      expect(theme.scaffoldBackgroundColor, AppTokens.pageLight);
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme uses the design dark surfaces', () {
      final theme = AppTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppTokens.pageDark);
      expect(theme.colorScheme.surface, AppTokens.cardDark);
    });

    test('the brand red is identical in both modes', () {
      // The design declares RED as a constant outside its theme map. An
      // earlier version of this theme lightened it for dark mode, which the
      // design does not do — this test exists to stop that coming back.
      expect(AppTheme.light().colorScheme.primary, AppTokens.brand);
      expect(AppTheme.dark().colorScheme.primary, AppTokens.brand);
    });

    test('both themes carry an AppPalette extension', () {
      expect(AppTheme.light().extension<AppPalette>(), isNotNull);
      expect(AppTheme.dark().extension<AppPalette>(), isNotNull);
    });

    test('uses Plus Jakarta Sans throughout', () {
      final theme = AppTheme.light();

      expect(theme.textTheme.titleLarge?.fontFamily, 'PlusJakartaSans');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
    });

    test('primary button matches the design CTA', () {
      final style = AppTheme.light().filledButtonTheme.style!;

      expect(
        style.minimumSize?.resolve({}),
        const Size.fromHeight(AppTokens.buttonHeight),
      );
      expect(style.textStyle?.resolve({})?.fontSize, 14);
      expect(style.textStyle?.resolve({})?.fontWeight, FontWeight.w700);
    });

    test('input fill and chip fill come from their own roles', () {
      final light = AppTheme.light();

      expect(light.inputDecorationTheme.fillColor, AppTokens.fieldLight);
      expect(light.chipTheme.backgroundColor, AppTokens.chipLight);
    });
  });

  group('AppTypography', () {
    test('sets weight on both fontWeight and the wght axis', () {
      // The bundled font is variable: without fontVariations every style
      // renders at the default weight, so this guards the whole type scale.
      final style = AppTypography.style(size: 14, weight: 800);

      expect(style.fontWeight, FontWeight.w800);
      expect(style.fontVariations, contains(const FontVariation('wght', 800)));
    });

    test('every style in the scale carries a wght variation', () {
      final styles = [
        AppTypography.textTheme.displaySmall,
        AppTypography.textTheme.headlineLarge,
        AppTypography.textTheme.titleLarge,
        AppTypography.textTheme.titleSmall,
        AppTypography.textTheme.bodyLarge,
        AppTypography.textTheme.bodyMedium,
        AppTypography.textTheme.bodySmall,
        AppTypography.textTheme.labelLarge,
        AppTypography.textTheme.labelMedium,
        AppTypography.textTheme.labelSmall,
      ];

      for (final style in styles) {
        expect(style, isNotNull);
        expect(
          style!.fontVariations,
          isNotEmpty,
          reason: 'a style with no wght axis renders at the default weight',
        );
      }
    });
  });

  group('AppPalette', () {
    testWidgets('resolves from the theme per brightness', (tester) async {
      Future<AppPalette> paletteFor(ThemeData theme) async {
        late AppPalette resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                resolved = AppPalette.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // MaterialApp animates between themes, and AppPalette.lerp takes part
        // in that, so the first frame after a theme swap still holds the old
        // palette. Settle before reading.
        await tester.pumpAndSettle();
        return resolved;
      }

      expect((await paletteFor(AppTheme.light())).page, AppTokens.pageLight);
      expect((await paletteFor(AppTheme.dark())).page, AppTokens.pageDark);
    });

    test('mirrors the design theme map, role for role', () {
      // Spot-check each role against the design's THEME object so a typo in
      // a hex is caught here rather than on a screen.
      final light = AppPalette.light();

      expect(light.page, AppTokens.pageLight);
      expect(light.bg, AppTokens.bgLight);
      expect(light.card, AppTokens.cardLight);
      expect(light.ink, AppTokens.inkLight);
      expect(light.muted, AppTokens.mutedLight);
      expect(light.muted2, AppTokens.muted2Light);
      expect(light.line, AppTokens.lineLight);
      expect(light.field, AppTokens.fieldLight);
      expect(light.chip, AppTokens.chipLight);
      expect(light.tint, AppTokens.tintLight);
      expect(light.contrast, AppTokens.contrastLight);
      expect(light.ring, AppTokens.ringLight);
      expect(light.okForeground, AppTokens.okFgLight);
      expect(light.warnForeground, AppTokens.warnFgLight);
      expect(light.tab, AppTokens.tabLight);
    });

    test('lerp moves every role, not just a few', () {
      final mixed = AppPalette.light().lerp(AppPalette.dark(), 1.0);

      expect(mixed.page, AppTokens.pageDark);
      expect(mixed.card, AppTokens.cardDark);
      expect(mixed.ink, AppTokens.inkDark);
      expect(mixed.line, AppTokens.lineDark);
      expect(mixed.okForeground, AppTokens.okFgDark);
      expect(mixed.tab, AppTokens.tabDark);
    });

    test('lerp covers every role the class declares', () {
      // lerp and copyWith both drive off one role list, so adding a role to
      // the class without adding it there would fail here.
      final half = AppPalette.light().lerp(AppPalette.dark(), 0.5);

      expect(half.page, isNot(AppTokens.pageLight));
      expect(half.page, isNot(AppTokens.pageDark));
    });
  });
}

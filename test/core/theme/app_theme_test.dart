import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_palette.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/core/theme/app_tokens.dart';
import 'package:food_menu/src/core/theme/app_typography.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses the design brand colour', () {
      final theme = AppTheme.light();

      expect(theme.colorScheme.primary, AppTokens.brand);
      expect(theme.scaffoldBackgroundColor, AppTokens.canvas);
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme lifts the brand colour off the dark surface', () {
      final theme = AppTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppTokens.brandDark);
      // The raw design red is deliberately not reused on dark surfaces.
      expect(theme.colorScheme.primary, isNot(AppTokens.brand));
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
  });

  group('AppTypography', () {
    test('sets weight on both fontWeight and the wght axis', () {
      // The bundled font is variable: without fontVariations every style
      // renders at the default weight, so this guards the whole type scale.
      final style = AppTypography.style(size: 14, weight: 800);

      expect(style.fontWeight, FontWeight.w800);
      expect(
        style.fontVariations,
        contains(const FontVariation('wght', 800)),
      );
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

      expect((await paletteFor(AppTheme.light())).brand, AppTokens.brand);
      expect((await paletteFor(AppTheme.dark())).brand, AppTokens.brandDark);
    });

    test('lerp moves every role, not just a few', () {
      final mixed = AppPalette.light().lerp(AppPalette.dark(), 1.0);

      expect(mixed.brand, AppTokens.brandDark);
      expect(mixed.canvas, AppTokens.canvasDark);
      expect(mixed.ink, AppTokens.inkDark);
      expect(mixed.border, AppTokens.borderDark);
    });
  });
}

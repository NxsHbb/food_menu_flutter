import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// The app's light and dark themes, built from the design tokens.
///
/// Both sets come from the design's own `THEME` map, so neither is invented.
/// Note that the brand red is the same in both modes by the design's own
/// declaration — it sits outside the theme map as a constant.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppPalette.light());

  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark());

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.brand,
      onPrimary: Colors.white,
      primaryContainer: palette.tint,
      onPrimaryContainer: palette.brand,
      secondary: palette.brand,
      onSecondary: Colors.white,
      error: palette.brand,
      onError: Colors.white,
      surface: palette.card,
      onSurface: palette.ink,
      onSurfaceVariant: palette.muted,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.field,
      surfaceContainer: palette.bg,
      surfaceContainerHigh: palette.chip,
      outline: palette.ring,
      outlineVariant: palette.line,
    );

    final textTheme = AppTypography.textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.page,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.page,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
      ),
      // The design's CTA: 48px tall, 14px radius, 14/700 label.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.line,
          disabledForegroundColor: palette.muted,
          minimumSize: const Size.fromHeight(AppTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size.fromHeight(AppTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: palette.ring),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brand,
          textStyle: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.field,
        hintStyle: textTheme.bodyLarge?.copyWith(color: palette.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space14,
          vertical: AppTokens.space14,
        ),
        border: _inputBorder(palette.line),
        enabledBorder: _inputBorder(palette.line),
        focusedBorder: _inputBorder(palette.brand, width: 1.5),
        errorBorder: _inputBorder(palette.brand),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.chip,
        selectedColor: palette.brand,
        side: BorderSide(color: palette.line),
        labelStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.tint,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusSheet),
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Semantic colour roles, resolved per brightness.
///
/// A `ThemeExtension` rather than a set of globals, so a widget reads
/// `AppPalette.of(context)` and automatically gets the right values in light
/// and dark without asking which mode it is in.
///
/// Roles the Material `ColorScheme` already covers are not duplicated here —
/// this holds only what the design needs and Material has no slot for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.brandPressed,
    required this.brandTintStrong,
    required this.brandTintSoft,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceFaint,
    required this.border,
    required this.borderStrong,
    required this.placeholderLight,
    required this.placeholderDark,
    required this.placeholderInk,
    required this.success,
    required this.star,
  });

  /// Light values, straight from the design.
  factory AppPalette.light() => const AppPalette(
        brand: AppTokens.brand,
        brandPressed: AppTokens.brandPressed,
        brandTintStrong: AppTokens.brandTintStrong,
        brandTintSoft: AppTokens.brandTintSoft,
        ink: AppTokens.ink,
        inkMuted: AppTokens.inkMuted,
        inkFaint: AppTokens.inkFaint,
        canvas: AppTokens.canvas,
        surface: AppTokens.surface,
        surfaceSubtle: AppTokens.surfaceSubtle,
        surfaceFaint: AppTokens.surfaceFaint,
        border: AppTokens.border,
        borderStrong: AppTokens.borderStrong,
        placeholderLight: AppTokens.placeholderLight,
        placeholderDark: AppTokens.placeholderDark,
        placeholderInk: AppTokens.placeholderInk,
        success: AppTokens.success,
        star: AppTokens.star,
      );

  /// Dark values, derived rather than designed — see `AppTokens`.
  factory AppPalette.dark() => const AppPalette(
        brand: AppTokens.brandDark,
        brandPressed: AppTokens.brandPressedDark,
        brandTintStrong: AppTokens.brandTintStrongDark,
        brandTintSoft: AppTokens.brandTintSoftDark,
        ink: AppTokens.inkDark,
        inkMuted: AppTokens.inkMutedDark,
        inkFaint: AppTokens.inkFaintDark,
        canvas: AppTokens.canvasDark,
        surface: AppTokens.surfaceDark,
        surfaceSubtle: AppTokens.surfaceSubtleDark,
        surfaceFaint: AppTokens.surfaceFaintDark,
        border: AppTokens.borderDark,
        borderStrong: AppTokens.borderStrongDark,
        placeholderLight: AppTokens.placeholderLightDark,
        placeholderDark: AppTokens.placeholderDarkDark,
        placeholderInk: AppTokens.placeholderInkDark,
        success: AppTokens.successDark,
        star: AppTokens.star,
      );

  final Color brand;
  final Color brandPressed;
  final Color brandTintStrong;
  final Color brandTintSoft;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceFaint;
  final Color border;
  final Color borderStrong;
  final Color placeholderLight;
  final Color placeholderDark;
  final Color placeholderInk;
  final Color success;
  final Color star;

  /// The palette for the nearest theme.
  ///
  /// Throws rather than falling back, because a missing palette means the
  /// widget is outside the app's theme and silently rendering wrong colours is
  /// worse than a loud failure in development.
  static AppPalette of(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>();
    assert(palette != null, 'AppPalette is missing from the current Theme.');
    return palette ?? AppPalette.light();
  }

  @override
  AppPalette copyWith({
    Color? brand,
    Color? brandPressed,
    Color? brandTintStrong,
    Color? brandTintSoft,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? canvas,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceFaint,
    Color? border,
    Color? borderStrong,
    Color? placeholderLight,
    Color? placeholderDark,
    Color? placeholderInk,
    Color? success,
    Color? star,
  }) {
    return AppPalette(
      brand: brand ?? this.brand,
      brandPressed: brandPressed ?? this.brandPressed,
      brandTintStrong: brandTintStrong ?? this.brandTintStrong,
      brandTintSoft: brandTintSoft ?? this.brandTintSoft,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceFaint: surfaceFaint ?? this.surfaceFaint,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      placeholderLight: placeholderLight ?? this.placeholderLight,
      placeholderDark: placeholderDark ?? this.placeholderDark,
      placeholderInk: placeholderInk ?? this.placeholderInk,
      success: success ?? this.success,
      star: star ?? this.star,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brand: mix(brand, other.brand),
      brandPressed: mix(brandPressed, other.brandPressed),
      brandTintStrong: mix(brandTintStrong, other.brandTintStrong),
      brandTintSoft: mix(brandTintSoft, other.brandTintSoft),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceSubtle: mix(surfaceSubtle, other.surfaceSubtle),
      surfaceFaint: mix(surfaceFaint, other.surfaceFaint),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      placeholderLight: mix(placeholderLight, other.placeholderLight),
      placeholderDark: mix(placeholderDark, other.placeholderDark),
      placeholderInk: mix(placeholderInk, other.placeholderInk),
      success: mix(success, other.success),
      star: mix(star, other.star),
    );
  }
}

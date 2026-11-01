import 'package:flutter/material.dart';

/// The design's type scale, in Plus Jakarta Sans.
///
/// The bundled font is a **variable** font, so a weight has to be set twice:
/// `fontWeight` for Flutter's layout and `fontVariations` to actually move the
/// `wght` axis. Setting only `fontWeight` renders every style at the default
/// weight, which looks like the theme silently ignoring the design.
abstract final class AppTypography {
  static const fontFamily = 'PlusJakartaSans';

  /// Builds a style with the weight applied to both axes.
  static TextStyle style({
    required double size,
    required int weight,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: _weightOf(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  static FontWeight _weightOf(int weight) {
    return switch (weight) {
      <= 400 => FontWeight.w400,
      500 => FontWeight.w500,
      600 => FontWeight.w600,
      700 => FontWeight.w700,
      _ => FontWeight.w800,
    };
  }

  /// The design's sizes run 10 → 26px; weights are 500, 600, 700 and 800.
  static final textTheme = TextTheme(
    // 26 / 24 — screen titles and the home greeting.
    displaySmall: style(size: 26, weight: 800, height: 1.15),
    headlineLarge: style(size: 24, weight: 800, height: 1.2),
    // 22 / 20 — prices and section figures.
    headlineMedium: style(size: 22, weight: 800, height: 1.2),
    headlineSmall: style(size: 20, weight: 800, height: 1.25),
    // 18 / 16 — card titles.
    titleLarge: style(size: 18, weight: 700, height: 1.3),
    titleMedium: style(size: 16, weight: 700, height: 1.35),
    // 15 / 14 — list row titles and button labels.
    titleSmall: style(size: 15, weight: 700, height: 1.35),
    bodyLarge: style(size: 14, weight: 500, height: 1.45),
    // 13 / 12 — secondary copy and meta rows.
    bodyMedium: style(size: 13, weight: 500, height: 1.45),
    bodySmall: style(size: 12, weight: 500, height: 1.4),
    // 11 / 10 — badges, chips and overlines.
    labelMedium: style(size: 11, weight: 700, height: 1.3),
    labelSmall: style(size: 10, weight: 700, height: 1.3, letterSpacing: 0.4),
    // Button label: 14 / 700, matching the design's CTA.
    labelLarge: style(size: 14, weight: 700, height: 1.2),
  );
}

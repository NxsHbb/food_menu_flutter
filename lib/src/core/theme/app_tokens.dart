import 'package:flutter/material.dart';

/// Raw values taken from the design, `designs/Food Ordering App.dc.html`.
///
/// Nothing outside this file should hard-code a hex, radius or spacing number.
/// Screens read semantic roles from [AppPalette] via the theme instead, so a
/// token change lands everywhere at once.
abstract final class AppTokens {
  // ---------------------------------------------------------------- palette
  /// Brand red. The design's single accent, used for CTAs, prices and links.
  static const brand = Color(0xFFF20800);
  static const brandPressed = Color(0xFFB80600);

  /// Brand tints, used for selected chips and soft badges.
  static const brandTintStrong = Color(0xFFFFE8E6);
  static const brandTintSoft = Color(0xFFFFF1F0);

  static const ink = Color(0xFF161616);
  static const inkMuted = Color(0xFF7A7A7A);
  static const inkFaint = Color(0xFF9A9A9A);

  /// The canvas behind the phone frames, and the app's own page background.
  static const canvas = Color(0xFFE9E7E4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF6F6F6);
  static const surfaceFaint = Color(0xFFFAFAFA);

  static const border = Color(0xFFEEEEEE);
  static const borderStrong = Color(0xFFE6E6E6);

  /// Image placeholder stripes, for dishes with no photo yet.
  static const placeholderLight = Color(0xFFEFEDEA);
  static const placeholderDark = Color(0xFFE6E3DF);
  static const placeholderInk = Color(0xFF8A8580);

  static const success = Color(0xFF0E8A6A);
  static const successBright = Color(0xFF23C69D);
  static const star = Color(0xFFFFB800);

  // ------------------------------------------------- dark mode (derived)
  // The design is light-only. These are derived from the tokens above, not
  // supplied: warm-neutral surfaces to match the warm light canvas, and a
  // lifted brand red because #F20800 on a dark surface reads muddy and its
  // contrast against white text is already marginal.
  static const brandDark = Color(0xFFFF5436);
  static const brandPressedDark = Color(0xFFD93A20);
  static const brandTintStrongDark = Color(0xFF3A1A14);
  static const brandTintSoftDark = Color(0xFF2A1512);

  static const inkDark = Color(0xFFF5F3F1);
  static const inkMutedDark = Color(0xFFA8A4A0);
  static const inkFaintDark = Color(0xFF807C78);

  static const canvasDark = Color(0xFF121110);
  static const surfaceDark = Color(0xFF1C1A19);
  static const surfaceSubtleDark = Color(0xFF242120);
  static const surfaceFaintDark = Color(0xFF1F1D1C);

  static const borderDark = Color(0xFF302C2A);
  static const borderStrongDark = Color(0xFF3C3734);

  static const placeholderLightDark = Color(0xFF2A2726);
  static const placeholderDarkDark = Color(0xFF221F1E);
  static const placeholderInkDark = Color(0xFF6E6964);

  static const successDark = Color(0xFF2ED3A5);

  // ----------------------------------------------------------------- shape
  /// Corner radii, from the design's 12 / 14 / 16 / 18 / 20 scale.
  static const radiusChip = 9.0;
  static const radiusControl = 12.0;
  static const radiusButton = 14.0;
  static const radiusCard = 16.0;
  static const radiusCardLarge = 18.0;
  static const radiusSheet = 20.0;

  // --------------------------------------------------------------- spacing
  /// The design's spacing run: 2 / 4 / 6 / 8 / 10 / 12 / 14 / 16.
  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space6 = 6.0;
  static const space8 = 8.0;
  static const space10 = 10.0;
  static const space12 = 12.0;
  static const space14 = 14.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;

  /// Height of the design's primary call to action.
  static const buttonHeight = 48.0;
}

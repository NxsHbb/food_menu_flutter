import 'package:flutter/material.dart';

/// Raw values from the design's own theme map.
///
/// Source: the `THEME` object in `designs/Food Ordering App.html`, which
/// defines a `light` and a `dark` set over the same role names and applies
/// them as CSS custom properties. The role names below mirror that map
/// one-to-one, so a value can be checked against the design without
/// translating vocabulary.
///
/// Nothing outside this file should hard-code a hex, radius or spacing number.
/// Screens read roles from [AppPalette] via the theme.
abstract final class AppTokens {
  // ------------------------------------------------------------------ brand
  /// `RED` in the design. **Deliberately identical in both modes** — the
  /// design declares it as a constant outside the theme map, so do not
  /// "improve" its dark-mode contrast without the designer agreeing.
  static const brand = Color(0xFFF20800);

  /// Hover/pressed red, from the design's stylesheet (`a:hover`).
  static const brandPressed = Color(0xFFB80600);

  // ------------------------------------------------------------ light theme
  /// `page` — the scaffold background.
  static const pageLight = Color(0xFFE9E7E4);

  /// `bg` — recessed panels inside a card.
  static const bgLight = Color(0xFFF6F6F6);

  /// `card` — the raised surface most content sits on.
  static const cardLight = Color(0xFFFFFFFF);

  static const inkLight = Color(0xFF161616);

  /// `muted` — secondary copy.
  static const mutedLight = Color(0xFF6E6E6E);

  /// `muted2` — between ink and muted; used where muted is too faint.
  static const muted2Light = Color(0xFF555555);

  /// `line` — hairline dividers and card borders.
  static const lineLight = Color(0xFFEEEEEE);

  /// `field` — text input fill.
  static const fieldLight = Color(0xFFFAFAFA);

  /// `chip` — unselected filter chip fill.
  static const chipLight = Color(0xFFEFEFEF);

  /// `ph1` / `ph2` — the two stripes of the no-photo placeholder.
  static const ph1Light = Color(0xFFEFEDEA);
  static const ph2Light = Color(0xFFE6E3DF);

  /// `tint` — soft brand wash behind selected and badged elements.
  static const tintLight = Color(0xFFFFE8E6);

  /// `contrast` — a deliberately high-contrast fill, e.g. a dark pill.
  static const contrastLight = Color(0xFF161616);

  /// `ring` — focus and emphasis outlines.
  ///
  /// **The one invented value in this file.** The design's light theme map
  /// has `ring: 'var(--ring)'`, which is self-referential and defined
  /// nowhere, so light mode has no ring colour to copy. This sits between
  /// [lineLight] and [mutedLight] so an outline reads as emphasis without
  /// becoming a border. Dark mode uses the design's own `#55555A`.
  /// Worth confirming with the designer.
  static const ringLight = Color(0xFFD8D8D8);

  /// `okbg` / `okfg` — success pair.
  static const okBgLight = Color(0xFFE0F7F0);
  static const okFgLight = Color(0xFF0E8A6A);

  /// `warnbg` / `warnfg` — warning pair.
  static const warnBgLight = Color(0xFFFFF3D6);
  static const warnFgLight = Color(0xFFA86A00);

  /// `tab` — inactive bottom-navigation item.
  static const tabLight = Color(0xFF9A9A9A);

  // ------------------------------------------------------------- dark theme
  // Neutral, not warm: the design's dark set is a cool grey ramp.
  static const pageDark = Color(0xFF0A0A0A);
  static const bgDark = Color(0xFF111112);
  static const cardDark = Color(0xFF1C1C1E);
  static const inkDark = Color(0xFFF4F4F5);
  static const mutedDark = Color(0xFFA1A1A6);
  static const muted2Dark = Color(0xFFC2C2C7);
  static const lineDark = Color(0xFF2C2C2E);
  static const fieldDark = Color(0xFF242426);
  static const chipDark = Color(0xFF2A2A2D);
  static const ph1Dark = Color(0xFF2A2826);
  static const ph2Dark = Color(0xFF222020);
  static const tintDark = Color(0xFF3B1412);
  static const contrastDark = Color(0xFF2C2C2E);
  static const ringDark = Color(0xFF55555A);
  static const okBgDark = Color(0xFF0F3328);
  static const okFgDark = Color(0xFF3FD6A8);
  static const warnBgDark = Color(0xFF3A2C0E);
  static const warnFgDark = Color(0xFFF2B84B);
  static const tabDark = Color(0xFF7C7C80);

  /// Star rating gold. Not in the theme map, so it is the same in both modes.
  static const star = Color(0xFFFFB800);

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

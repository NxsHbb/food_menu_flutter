import 'package:material_ui/material_ui.dart';

/// Turning a store's chosen brand colour into one this app can draw.
///
/// **The app draws white on the brand, everywhere.** The header, the primary
/// button, the badges, the quick-add — the design says so and the widgets say
/// so in their own comments. Honouring a store's colour therefore has two
/// possible answers when that colour is pale: flip every foreground to dark,
/// or keep white and make the colour dark enough to carry it.
///
/// This takes the second. Flipping foregrounds would mean a derived
/// `onBrand` threaded through some twenty-five call sites, and a store that
/// picked a pale yellow would get an app that looks nothing like the one the
/// design describes — light text in some places and dark in others, decided
/// per widget. Darkening keeps one rule for the whole app: **white on brand,
/// and the brand is always dark enough to mean it.**
///
/// The cost is honest and worth stating: a store that sets a pale colour sees
/// a deeper version of it in the app than on its website. The hue is theirs;
/// the legibility is ours.
abstract final class BrandColor {
  /// Minimum contrast ratio white text must reach against the brand.
  ///
  /// **3.0, not 4.5, and measured rather than assumed.** WCAG AA asks 4.5:1
  /// for body text and 3:1 for large text and UI components. The app's own
  /// red, `#fc202e`, comes to **3.9:1** against white — so a 4.5 bar here
  /// would have quietly darkened the design's own colour on every screen, in
  /// a task about honouring somebody else's.
  ///
  /// 3:1 is the bar the brand is actually held to: it is a background for
  /// button labels, header text and badges, which is the large-text and
  /// UI-component case. A store colour that lands between 3.0 and 4.5 will
  /// read exactly as well as the app's own does today, which is the honest
  /// promise to make. Whether the design's red should move at all is task
  /// 14.9's question, not this one's.
  static const minimumContrast = 3.0;

  /// The store's colour, darkened only as far as white legibility needs.
  ///
  /// Returns [brand] unchanged when it already passes, which is the case for
  /// every default install.
  static Color resolve(Color brand) {
    if (_contrastWithWhite(brand) >= minimumContrast) return brand;

    final hsl = HSLColor.fromColor(brand);

    // Walk the lightness down in small steps rather than solving for it: the
    // relationship between HSL lightness and relative luminance is not linear
    // and depends on the hue, so the closed form would be wrong for exactly
    // the colours this exists to handle.
    for (var lightness = hsl.lightness; lightness >= 0; lightness -= 0.01) {
      final candidate = hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
      if (_contrastWithWhite(candidate) >= minimumContrast) return candidate;
    }

    // Unreachable in practice — black passes against white — but a loop that
    // can fall out of the bottom should say what it does when it gets there.
    return const Color(0xFF000000);
  }

  /// The pressed state: a touch deeper than the resolved brand.
  static Color pressed(Color brand) {
    final hsl = HSLColor.fromColor(brand);

    return hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
  }

  /// The soft brand wash behind lettered tiles and selected chips.
  ///
  /// Blended toward the surface it sits on rather than made translucent, so it
  /// stays a solid colour the way the design tokens are.
  static Color tint(Color brand, Color surface) {
    return Color.lerp(surface, brand, 0.12) ?? surface;
  }

  /// WCAG contrast ratio between white and [colour].
  static double _contrastWithWhite(Color colour) {
    // `computeLuminance` is already the WCAG relative luminance, and white's
    // is 1.0.
    return 1.05 / (colour.computeLuminance() + 0.05);
  }
}

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Semantic colour roles, resolved per brightness.
///
/// The role names mirror the design's own `THEME` map, so a value here can be
/// checked against `designs/Food Ordering App.html` without translating
/// vocabulary. A `ThemeExtension` rather than globals, so a widget reads
/// `AppPalette.of(context)` and gets the right set in either mode without
/// asking which one is active.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.brandPressed,
    required this.page,
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.muted2,
    required this.line,
    required this.field,
    required this.chip,
    required this.placeholderStripe1,
    required this.placeholderStripe2,
    required this.tint,
    required this.contrast,
    required this.ring,
    required this.okBackground,
    required this.okForeground,
    required this.warnBackground,
    required this.warnForeground,
    required this.tab,
    required this.star,
  });

  factory AppPalette.light() => const AppPalette(
        brand: AppTokens.brand,
        brandPressed: AppTokens.brandPressed,
        page: AppTokens.pageLight,
        bg: AppTokens.bgLight,
        card: AppTokens.cardLight,
        ink: AppTokens.inkLight,
        muted: AppTokens.mutedLight,
        muted2: AppTokens.muted2Light,
        line: AppTokens.lineLight,
        field: AppTokens.fieldLight,
        chip: AppTokens.chipLight,
        placeholderStripe1: AppTokens.ph1Light,
        placeholderStripe2: AppTokens.ph2Light,
        tint: AppTokens.tintLight,
        contrast: AppTokens.contrastLight,
        ring: AppTokens.ringLight,
        okBackground: AppTokens.okBgLight,
        okForeground: AppTokens.okFgLight,
        warnBackground: AppTokens.warnBgLight,
        warnForeground: AppTokens.warnFgLight,
        tab: AppTokens.tabLight,
        star: AppTokens.star,
      );

  factory AppPalette.dark() => const AppPalette(
        // Same red as light, by the design's own declaration.
        brand: AppTokens.brand,
        brandPressed: AppTokens.brandPressed,
        page: AppTokens.pageDark,
        bg: AppTokens.bgDark,
        card: AppTokens.cardDark,
        ink: AppTokens.inkDark,
        muted: AppTokens.mutedDark,
        muted2: AppTokens.muted2Dark,
        line: AppTokens.lineDark,
        field: AppTokens.fieldDark,
        chip: AppTokens.chipDark,
        placeholderStripe1: AppTokens.ph1Dark,
        placeholderStripe2: AppTokens.ph2Dark,
        tint: AppTokens.tintDark,
        contrast: AppTokens.contrastDark,
        ring: AppTokens.ringDark,
        okBackground: AppTokens.okBgDark,
        okForeground: AppTokens.okFgDark,
        warnBackground: AppTokens.warnBgDark,
        warnForeground: AppTokens.warnFgDark,
        tab: AppTokens.tabDark,
        star: AppTokens.star,
      );

  /// `RED`. Identical in both modes, per the design.
  final Color brand;
  final Color brandPressed;

  /// `page` — scaffold background.
  final Color page;

  /// `bg` — recessed panel inside a card.
  final Color bg;

  /// `card` — raised content surface.
  final Color card;
  final Color ink;

  /// `muted` — secondary copy.
  final Color muted;

  /// `muted2` — stronger than [muted], weaker than [ink].
  final Color muted2;

  /// `line` — dividers and card borders.
  final Color line;

  /// `field` — input fill.
  final Color field;

  /// `chip` — unselected chip fill.
  final Color chip;

  /// `ph1` / `ph2` — no-photo placeholder stripes.
  final Color placeholderStripe1;
  final Color placeholderStripe2;

  /// `tint` — soft brand wash.
  final Color tint;

  /// `contrast` — high-contrast fill.
  final Color contrast;

  /// `ring` — focus and emphasis outlines.
  final Color ring;

  final Color okBackground;
  final Color okForeground;
  final Color warnBackground;
  final Color warnForeground;

  /// `tab` — inactive navigation item.
  final Color tab;

  final Color star;

  /// The palette for the nearest theme.
  static AppPalette of(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>();
    assert(palette != null, 'AppPalette is missing from the current Theme.');
    return palette ?? AppPalette.light();
  }

  /// Every role, in declaration order. Used by [copyWith] and [lerp] so a new
  /// role cannot be added to the class and silently forgotten by both.
  List<Color> get _roles => [
        brand,
        brandPressed,
        page,
        bg,
        card,
        ink,
        muted,
        muted2,
        line,
        field,
        chip,
        placeholderStripe1,
        placeholderStripe2,
        tint,
        contrast,
        ring,
        okBackground,
        okForeground,
        warnBackground,
        warnForeground,
        tab,
        star,
      ];

  AppPalette _fromRoles(List<Color> r) => AppPalette(
        brand: r[0],
        brandPressed: r[1],
        page: r[2],
        bg: r[3],
        card: r[4],
        ink: r[5],
        muted: r[6],
        muted2: r[7],
        line: r[8],
        field: r[9],
        chip: r[10],
        placeholderStripe1: r[11],
        placeholderStripe2: r[12],
        tint: r[13],
        contrast: r[14],
        ring: r[15],
        okBackground: r[16],
        okForeground: r[17],
        warnBackground: r[18],
        warnForeground: r[19],
        tab: r[20],
        star: r[21],
      );

  @override
  AppPalette copyWith({
    Color? brand,
    Color? brandPressed,
    Color? page,
    Color? bg,
    Color? card,
    Color? ink,
    Color? muted,
    Color? muted2,
    Color? line,
    Color? field,
    Color? chip,
    Color? placeholderStripe1,
    Color? placeholderStripe2,
    Color? tint,
    Color? contrast,
    Color? ring,
    Color? okBackground,
    Color? okForeground,
    Color? warnBackground,
    Color? warnForeground,
    Color? tab,
    Color? star,
  }) {
    return AppPalette(
      brand: brand ?? this.brand,
      brandPressed: brandPressed ?? this.brandPressed,
      page: page ?? this.page,
      bg: bg ?? this.bg,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      muted2: muted2 ?? this.muted2,
      line: line ?? this.line,
      field: field ?? this.field,
      chip: chip ?? this.chip,
      placeholderStripe1: placeholderStripe1 ?? this.placeholderStripe1,
      placeholderStripe2: placeholderStripe2 ?? this.placeholderStripe2,
      tint: tint ?? this.tint,
      contrast: contrast ?? this.contrast,
      ring: ring ?? this.ring,
      okBackground: okBackground ?? this.okBackground,
      okForeground: okForeground ?? this.okForeground,
      warnBackground: warnBackground ?? this.warnBackground,
      warnForeground: warnForeground ?? this.warnForeground,
      tab: tab ?? this.tab,
      star: star ?? this.star,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    final mine = _roles;
    final theirs = other._roles;
    return _fromRoles([
      for (var i = 0; i < mine.length; i++) Color.lerp(mine[i], theirs[i], t)!,
    ]);
  }
}

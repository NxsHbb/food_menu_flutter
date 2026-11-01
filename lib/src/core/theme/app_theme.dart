import 'package:flutter/material.dart';

/// Interim theme.
///
/// Phase 1.3 replaces this with the real design system once the supplied
/// design is available. Until then this is deliberately plain Material 3 with
/// a single seed colour, so no made-up brand values leak into screens and
/// later have to be hunted down.
abstract final class AppTheme {
  /// Placeholder seed. Not a brand colour — see the class doc.
  static const _seed = Color(0xFFD84315);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}

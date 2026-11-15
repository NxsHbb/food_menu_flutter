import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's own font before any test runs.
///
/// Without this, `flutter test` draws every glyph in a fallback font that is
/// **wider** than Plus Jakarta Sans, so anything the suite says about whether
/// content *fits* is measured against a typeface the app never uses. Two rows
/// — the dish screen's add bar and the reviews section's message — overflow a
/// 390dp phone under the fallback font and neither overflows under the real
/// one. Both would have read as layout bugs.
///
/// The error runs the other way too: a row that only just fits in the
/// fallback font would pass a no-overflow test while being broken in the app.
/// Either way the font has to be the real one for the question to mean
/// anything, and `flutter_test_config.dart` is the one place that covers every
/// test file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final loader = FontLoader('PlusJakartaSans')
    ..addFont(
      Future.value(
        File('assets/fonts/PlusJakartaSans-Variable.ttf')
            .readAsBytesSync()
            .buffer
            .asByteData(),
      ),
    );
  await loader.load();

  await testMain();
}

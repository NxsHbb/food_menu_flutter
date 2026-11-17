import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../journeys/journey_harness.dart';

/// Every screen, drawn at the text size a customer can actually choose.
///
/// **Android's accessibility slider reaches 2.0 and iOS goes past it**, and
/// nothing in this app had been drawn above 1.0 before task 14.9. A layout
/// sized by text fails loudly — a yellow-and-black overflow bar in debug,
/// silently clipped words in release — and which of those a customer gets
/// depends only on the build they install.
///
/// The sweep walks the **shipped router** rather than pumping screens one at
/// a time, so the shell, the tabs and the bars floating over them are all in
/// the picture together. The add-to-cart bar this first caught belongs to no
/// screen's own test: it is painted over the dish screen by the shell.
///
/// It is deliberately a smoke test rather than a golden. It answers "does
/// anything fall off the edge", which is the failure that reaches a customer
/// as missing words, and leaves "does it look right" to a person.
void main() {
  /// Overflow reaches a test as a `FlutterError` on the exception channel.
  /// Collected rather than rethrown, so one run reports every screen instead
  /// of stopping at the first and hiding the rest behind it.
  List<String> overflowsDuring(WidgetTester tester) {
    final found = <String>[];
    var error = tester.takeException();
    while (error != null) {
      final text = error.toString();
      if (text.contains('overflowed')) found.add(text.split('\n').first);
      error = tester.takeException();
    }
    return found;
  }

  /// Drags each scrollable to its end: a row that overflows below the fold
  /// has not been laid out yet and reports nothing.
  Future<void> scrollThrough(
    WidgetTester tester,
    String where,
    List<String> problems,
  ) async {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) return;

    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable.first, const Offset(0, -400));
      await tester.pumpAndSettle();
      problems.addAll(overflowsDuring(tester).map((e) => '$where scrolled: $e'));
    }
  }

  /// Leaves a pushed screen. Popped rather than `tester.pageBack()`, which
  /// insists on a Cupertino back button the app does not draw.
  Future<void> pop(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Navigator).last)).pop();
    await tester.pumpAndSettle();
  }

  Future<void> visit(
    WidgetTester tester,
    String label,
    List<String> problems,
  ) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
    problems.addAll(overflowsDuring(tester).map((e) => '$label: $e'));
    await scrollThrough(tester, label, problems);
  }

  Future<void> sweep(WidgetTester tester, double scale) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = JourneyHarness();
    final problems = <String>[];

    // **A real phone's height.** The journey harness uses a 2400dp viewport
    // so cards below the fold are built and can be tapped, which is right
    // for a journey and useless here: nothing overflows vertically on a
    // screen that tall, so the sweep would pass by construction.
    await harness.pump(tester, size: const Size(390, 844));
    problems.addAll(overflowsDuring(tester).map((e) => 'menu: $e'));
    await scrollThrough(tester, 'menu', problems);

    // The dish screen: the densest layout in the app — a price block, a
    // stepper, add-on groups and the add bar, all sized by text.
    await visit(tester, 'Fresh Lemonade', problems);
    await pop(tester);

    for (final tab in ['Cart', 'Orders', 'Account']) {
      await visit(tester, tab, problems);
    }

    // Reached from the account screen and nowhere else, so a sweep that
    // stopped at the tabs would never draw them.
    for (final row in ['Wishlist', 'Saved addresses']) {
      await visit(tester, row, problems);
      await pop(tester);
    }

    expect(
      problems,
      isEmpty,
      reason: 'at text scale $scale:\n${problems.join('\n')}',
    );
  }

  testWidgets('every screen draws at the system text size', (tester) async {
    await sweep(tester, 1);
  });

  testWidgets('and at 1.5, the step most people who change it pick',
      (tester) async {
    await sweep(tester, 1.5);
  });

  testWidgets("and at 2.0, the end of Android's own slider", (tester) async {
    await sweep(tester, 2);
  });
}

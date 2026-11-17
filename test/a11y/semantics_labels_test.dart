import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../journeys/journey_harness.dart';

/// Nothing a customer can tap should be nameless (task 14.9).
///
/// TalkBack and VoiceOver read a control's **label**. A `+` or a `−` has no
/// text, so an icon-only button with nothing else announces as "button" — and
/// this app's way into the cart, its quantity controls and the way off half
/// its screens were all exactly that.
///
/// The audit is run rather than reviewed: the semantics tree is walked for
/// nodes that accept a tap and carry no name, which is the same question a
/// screen reader asks. A grep for `Semantics(` could only ever find the
/// places somebody already thought about.
void main() {
  /// Every tappable node with no name, as `rect — tooltip` for the report.
  ///
  /// **A tooltip counts.** `IconButton(tooltip: …)` is the framework's own way
  /// of naming an icon button and screen readers announce it, so the address
  /// card's `⋮` is correctly named even with an empty `label`.
  /// How many nodes every walk visited between them, so a traversal that
  /// silently reaches nothing cannot pass as a clean result.
  var visited = 0;

  List<String> namelessTappables(WidgetTester tester) {
    final found = <String>[];

    void walk(SemanticsNode node) {
      visited++;
      final data = node.getSemanticsData();
      final named =
          data.label.trim().isNotEmpty || data.tooltip.trim().isNotEmpty;

      if (data.hasAction(SemanticsAction.tap) && !named) {
        found.add('${node.rect.size}');
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    // `tester.binding.pipelineOwner` is deprecated; the semantics of a test's
    // single view hang off the root owner's child.
    final root = tester.binding.rootPipelineOwner.semanticsOwner
            ?.rootSemanticsNode ??
        _firstSemanticsRoot(tester.binding.rootPipelineOwner);
    walk(root!);

    return found;
  }


  testWidgets('every tappable on every screen has a name', (tester) async {
    // Disposed at the end of the body, not through `addTearDown`: the
    // framework verifies no handle is outstanding *before* tear-downs run.
    final handle = tester.ensureSemantics();

    final harness = JourneyHarness();
    await harness.pump(tester, size: const Size(390, 844));

    final problems = <String>[];

    void check(String where) {
      problems.addAll(namelessTappables(tester).map((n) => '$where: $n'));
    }

    Future<void> pop() async {
      Navigator.of(tester.element(find.byType(Navigator).last)).pop();
      await tester.pumpAndSettle();
    }

    check('menu');

    await tester.tap(find.text('Fresh Lemonade').first);
    await tester.pumpAndSettle();
    check('dish');
    await pop();

    for (final tab in ['Cart', 'Orders', 'Account']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      check(tab);
    }

    for (final row in ['Wishlist', 'Saved addresses']) {
      await tester.tap(find.text(row).first);
      await tester.pumpAndSettle();
      check(row);
      await pop();
    }

    handle.dispose();

    // A walk that reached nothing would report no problems and mean nothing.
    expect(visited, greaterThan(100), reason: 'semantics tree not traversed');

    expect(
      problems,
      isEmpty,
      reason: 'tappable but nameless to a screen reader:\n'
          '${problems.join('\n')}',
    );
  });

  testWidgets('the quick-add button says what the tap will do',
      (tester) async {
    // Disposed at the end of the body, not through `addTearDown`: the
    // framework verifies no handle is outstanding *before* tear-downs run.
    final handle = tester.ensureSemantics();

    final harness = JourneyHarness();
    await harness.pump(tester, size: const Size(390, 844));

    // **Fresh Lemonade needs choices, so its `+` opens the dish screen** and
    // does not add anything. Promising "add" there would be a lie told only
    // to the customer who cannot see that a screen opened instead.
    expect(
      find.bySemanticsLabel('Choose options for Fresh Lemonade'),
      findsOneWidget,
    );
    // Margherita has none, so its `+` really does add.
    expect(
      find.bySemanticsLabel('Add Margherita to cart'),
      findsOneWidget,
    );

    handle.dispose();
  });
}

/// The semantics root of the first child owner that has one.
///
/// A test binding puts the view's own `PipelineOwner` under the root rather
/// than on it, so the root's `semanticsOwner` is null.
SemanticsNode? _firstSemanticsRoot(PipelineOwner owner) {
  SemanticsNode? found;
  owner.visitChildren((child) {
    found ??= child.semanticsOwner?.rootSemanticsNode ??
        _firstSemanticsRoot(child);
  });
  return found;
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

/// Whether the router still builds **Material** pages.
///
/// go_router does not take the app's word for which page type to use. It
/// looks up the tree for a `MaterialApp` **by exact type** and falls back to
/// `NoTransitionPage` for every route when it cannot find one. All twenty of
/// the app's routes are declared with `builder:`, so every one goes through
/// that lookup.
///
/// That is what made task 11.4 a silent risk: `material_ui`'s `MaterialApp`
/// is a different type from the SDK's, so on go_router 17 the lookup failed
/// and the whole app lost its push and pop animations — with the entire
/// suite still green, because every test `pumpAndSettle`s and a cut settles
/// just as well as a transition. Measured, on this journey: go_router 17.5.0
/// built `NoTransitionPage` for both routes, 18.1.4 builds `MaterialPage`.
///
/// So this asserts the page type the router actually produced, which is the
/// thing that silently changed. It is the reason the go_router bump belongs
/// with the import swap rather than after it.
void main() {
  journeyTest('the router builds Material pages, not transitionless ones',
      (tester) async {
    final harness = JourneyHarness();
    await harness.pump(tester);

    await tester.tap(find.text('Fresh Lemonade').first);
    await tester.pumpAndSettle();

    final pages = [
      for (final nav in tester.widgetList<Navigator>(find.byType(Navigator)))
        ...nav.pages,
    ];

    expect(pages, isNotEmpty, reason: 'the router should be driving pages');
    expect(
      pages.whereType<MaterialPage>(),
      hasLength(pages.length),
      reason: 'every route should be a MaterialPage. NoTransitionPage here '
          'means go_router could not find the MaterialApp and fell back, '
          'which costs every transition in the app silently',
    );
  });
}

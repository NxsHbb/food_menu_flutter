import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/checkout/domain/checkout_config.dart';
import 'package:food_menu/src/features/checkout/presentation/widgets/checkout_card.dart';

import 'checkout_harness.dart';

/// The gaps between the checkout's cards, task 15.3.
///
/// The screen separates every section by `AppTokens.space12`, and three of
/// them — shipping, the tip, payment — were placed back to back with nothing
/// between. Habib noticed it on the tip, which sits between the other two and
/// so was squeezed at both ends.
///
/// **The gap cannot live in the parent**, which is why this is not a two-line
/// fix and why it is worth a test: `ShippingSection` returns
/// `SizedBox.shrink()` on three paths and `TipSection` on two, so a `SizedBox`
/// in the screen's list would outlive the card it was spacing — a pickup
/// order with tips off would show two gaps in an empty stretch of screen.
/// Each optional section carries its own bottom gap instead.
///
/// So these measure the **drawn** cards rather than the widgets: a hidden
/// section has no box and should leave no trace of itself between its
/// neighbours.
void main() {
  /// Every card on the screen, top to bottom, as rectangles.
  List<Rect> cards(WidgetTester tester) {
    final found = find.byType(CheckoutCard);
    final rects = [
      for (var i = 0; i < found.evaluate().length; i++) tester.getRect(found.at(i)),
    ];
    rects.sort((a, b) => a.top.compareTo(b.top));
    return rects;
  }

  /// The vertical space between each card and the next.
  List<double> gaps(WidgetTester tester) {
    final rects = cards(tester);
    return [
      for (var i = 1; i < rects.length; i++)
        double.parse((rects[i].top - rects[i - 1].bottom).toStringAsFixed(2)),
    ];
  }

  testWidgets('every card is the same distance from the next', (tester) async {
    final harness = CheckoutHarness();
    await harness.pump(tester);

    final measured = gaps(tester);

    expect(measured, isNotEmpty);
    expect(measured, everyElement(12.0), reason: 'cards: ${cards(tester).length}');
  });

  testWidgets('a store with tips off leaves no gap where the tip was',
      (tester) async {
    // The reported case. With the gap in the parent this came out at 24 —
    // the tip's own spacing surviving the tip.
    final harness = CheckoutHarness()
      ..checkout.sectionsAnswer = const CheckoutSections(
        orderType: true,
        yourLocation: true,
        orderNotes: true,
        tips: false,
      );
    await harness.pump(tester);

    expect(find.text('Add a tip'), findsNothing);
    expect(gaps(tester), everyElement(12.0));
  });

  testWidgets('a pickup order leaves no gap where the delivery method was',
      (tester) async {
    // `ShippingSection`'s first way out: pickup collects no delivery method.
    final harness = CheckoutHarness();
    await harness.pump(tester);

    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery method'), findsNothing);
    expect(gaps(tester), everyElement(12.0));
  });

  testWidgets('a pickup order with tips off still spaces evenly',
      (tester) async {
    // Both optional sections gone at once, which is the arrangement that
    // would have shown two stray gaps in a row.
    final harness = CheckoutHarness()
      ..checkout.sectionsAnswer = const CheckoutSections(
        orderType: true,
        yourLocation: true,
        orderNotes: true,
        tips: false,
      );
    await harness.pump(tester);

    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery method'), findsNothing);
    expect(find.text('Add a tip'), findsNothing);
    expect(gaps(tester), everyElement(12.0));
  });

  testWidgets('a signed-out checkout does not run into the section below',
      (tester) async {
    // The sign-in card had no gap under it either, for the same reason
    // nobody had noticed: it is only drawn on one branch of the screen.
    final harness = CheckoutHarness();
    await harness.pump(tester, signedIn: false);

    expect(find.text('Sign in to order'), findsOneWidget);
    expect(gaps(tester), everyElement(12.0));
  });
}

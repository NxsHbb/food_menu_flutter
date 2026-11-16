import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

/// Signing in from the middle of a checkout, and coming back to it.
///
/// `checkout_screen_test.dart` proves the prompt replaces the address card
/// and that it leads somewhere, but it pushes a **stub** login route — so
/// what it really asserts is that a route name was pushed. The part that
/// matters to a customer is the return: the auth screens sit outside the
/// shell and are pushed precisely so that popping lands back on the order
/// they were halfway through, with the cart and the chosen time intact.
void main() {
  group('a signed-out customer at the checkout', () {
    journeyTest('is asked for an account instead of being allowed to order',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      );
      await harness.pump(tester, signedIn: false);

      await harness.openCartTab(tester);
      await harness.tapIn(tester, find.text('Go to checkout'));

      expect(find.text('Sign in to order'), findsOneWidget);
      // The cart is still theirs to see — being signed out is not a reason to
      // hide what they were buying.
      expect(find.text(r'2× Fresh Lemonade'), findsOneWidget);

      // The button stays, and says what is missing when it is pressed: the
      // design keeps it live rather than leaving a dead control to deduce.
      await harness.tapIn(tester, find.text('Place order'));
      expect(find.text('Sign in to place your order.'), findsOneWidget);
      expect(harness.checkout.drafts, isEmpty);
    });

    journeyTest('signs in and comes back to the order, not to the menu',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      );
      harness.checkout.order = placedOrder(id: 62, number: '62');
      await harness.pump(tester, signedIn: false);

      await harness.openCartTab(tester);
      await harness.tapIn(tester, find.text('Go to checkout'));
      await harness.tapIn(tester, find.text('Sign in'));

      // The real login screen, reached through the shipped router.
      expect(find.text('Welcome back'), findsWidgets);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'customer@foodmenu.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Customer@2020##',
      );
      await harness.tapIn(tester, find.text('Sign in').last);

      // Back on the checkout, which is now a checkout they can finish: the
      // address book arrived with the account and the prompt is gone.
      expect(find.text('Sign in to order'), findsNothing);
      expect(find.text('6391 Elgin St.'), findsOneWidget);
      expect(find.text('Place order'), findsOneWidget);

      // And the cart it was opened on is still the cart being ordered.
      await harness.tapIn(tester, find.text('Place order'));
      expect(harness.checkout.drafts.single.expectedTotal, '2350');
      expect(find.text('#62'), findsOneWidget);
    });
  });
}

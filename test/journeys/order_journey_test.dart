import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/cart/presentation/widgets/quick_add_button.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';

import 'journey_harness.dart';

/// The whole order path, through the real router.
///
/// Every screen here has its own test file, and each of those is the better
/// place to ask what a screen draws. What none of them can ask is whether the
/// screens **connect**: they each pump one screen with a stub where the next
/// one belongs, so a handoff could be broken in the shipped router and all of
/// them would still pass.
///
/// The journey is one captured order: dish 25 at $3.25, `Medium 12"` at
/// $2.50, `Mushrooms` twice at $0.75, a note, two of them — which is the cart
/// in `cart_with_addons.json`, a real response from the dev store. That is why
/// the numbers below are not round: they are the store's, not the test's.
void main() {
  group('a dish with add-ons reaches a placed order', () {
    journeyTest('the whole path, one screen handing to the next',
        (tester) async {
      final harness = JourneyHarness();
      // So the order placed and the order read back are the same one. The
      // checkout answers with an id and the received screen re-reads it, which
      // is two fakes that have to agree.
      harness.checkout.order = placedOrder(id: 62, number: '62');
      await harness.pump(tester);

      // --- the menu -------------------------------------------------------
      expect(find.text('Fresh Lemonade'), findsOneWidget);
      // Nothing in the cart, so nothing in the way of it.
      expect(find.text('View cart'), findsNothing);

      // --- the dish -------------------------------------------------------
      await tester.tap(find.text('Fresh Lemonade').first);
      await tester.pumpAndSettle();

      // The store's required question arrives answered with its own default,
      // so the price starts at the dish plus nothing.
      expect(find.text('Choose your size'), findsOneWidget);
      expect(priceOnButton(r'$3.25'), findsOneWidget);

      await harness.tapIn(tester, find.text('Medium 12"'));
      expect(priceOnButton(r'$5.75'), findsOneWidget);

      await harness.tapIn(tester, find.text('Mushrooms'));
      expect(priceOnButton(r'$6.50'), findsOneWidget);

      // The option's own stepper, which only exists once it is ticked and
      // sits above the bottom bar's.
      await harness.tapIn(tester, find.byIcon(Icons.add).first);
      expect(priceOnButton(r'$7.25'), findsOneWidget);

      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'No ice please');
      await tester.pumpAndSettle();

      // Two of them: the bottom bar's stepper, not an option's.
      await harness.tapIn(tester, find.byIcon(Icons.add).last);
      expect(priceOnButton(r'$14.50'), findsOneWidget);

      // --- the add --------------------------------------------------------
      // What the server answers this add with. The app does not work the cart
      // out, so the journey hands over the captured response rather than
      // letting a fake price the plugin's add-ons.
      harness.cart.writeAnswers.add(cartFromFixture('cart_with_addons'));

      await harness.tapIn(tester, find.text('Add to cart'));

      // The dish sent what the screen was showing.
      expect(harness.cart.calls.last, 'add 25 x2');
      expect(harness.cart.addonPayloads.single, [
        {'group_id': '0', 'option_ids': ['1']},
        {
          'group_id': '1',
          'option_ids': ['0'],
          'quantities': {'0': 2},
        },
        {'group_id': '2', 'text': 'No ice please'},
      ]);

      // --- back on the menu, with a cart ----------------------------------
      // The dish closed itself, and the bar that was absent a moment ago is
      // now offering the cart it filled.
      expect(find.text('Fresh Lemonade'), findsOneWidget);
      expect(find.text('View cart'), findsOneWidget);
      // Three units across the two lines of the captured cart.
      expect(find.widgetWithText(Badge, '3'), findsOneWidget);
      // Named, so the customer can tell which dish landed when they have
      // tapped + on several.
      expect(find.text(r'2× Fresh Lemonade added'), findsOneWidget);

      // --- the cart -------------------------------------------------------
      // The confirmation sits **over** the cart bar, so a tap on `View cart`
      // lands on the snackbar until it retires. Found here: the one-screen
      // tests each own one of these two widgets and never have both.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await harness.tapIn(tester, find.text('View cart'));

      expect(find.text('My cart'), findsOneWidget);
      // The add-ons chosen on the dish screen, read back off the line the
      // server answered with — the two halves of the add-on feature meeting.
      expect(find.textContaining('Medium 12"'), findsWidgets);
      expect(find.textContaining('Mushrooms'), findsWidgets);
      expect(find.text(r'$14.50'), findsWidgets);

      // --- the handoff the plan names --------------------------------------
      await harness.tapIn(tester, find.text('Go to checkout'));

      expect(find.text('Checkout'), findsWidgets);
      // The checkout asked for times for the cart it was handed, not for an
      // empty one: availability depends on what is being ordered.
      expect(harness.fulfilment.calls.where((c) => c.startsWith('slots')),
          isNotEmpty);
      expect(harness.fulfilment.calls.last, contains('25:2'));

      // --- a slot ----------------------------------------------------------
      await harness.tapIn(tester, find.text('11:30 pm – 11:45 pm'));

      // --- placing it ------------------------------------------------------
      await harness.tapIn(tester, find.text('Place order'));

      // The order carries the cart, the address book's default, the account's
      // phone and the slot that was tapped.
      final extension = harness.checkout.lastExtension;
      expect(extension['fmp_order_time_type'], 'delivery');
      expect(extension['fmp_delivery_date'], 'November 10, 2026');
      expect(extension['fmp_delivery_time'], '11:30 pm');

      final draft = harness.checkout.drafts.single;
      expect(draft.contact.phone, '01711 000111');
      expect(draft.address.address1, '6391 Elgin St.');
      // The total the customer was shown on the cart and the bar.
      expect(draft.expectedTotal, '2350');

      // --- the order received screen ----------------------------------------
      expect(find.text('Order placed!'), findsOneWidget);
      expect(find.text('#62'), findsOneWidget);
      // Read back by the id the checkout answered with, rather than drawn
      // from what was submitted.
      expect(harness.orders.requested, [62]);
    });

    journeyTest('a dish with nothing to choose goes straight in from the menu',
        (tester) async {
      final harness = JourneyHarness();
      await harness.pump(tester);

      // The captured cart carries a Margherita line, so it is what this add
      // can honestly come back as.
      harness.cart.writeAnswers.add(cartFromFixture('cart_with_addons'));

      // Margherita has no groups, so the card's + is the whole interaction —
      // no dish screen in between.
      await harness.tapIn(tester, quickAddFor('Margherita'));

      expect(harness.cart.calls.last, 'add 14 x1');
      expect(harness.cart.addonPayloads.single, isEmpty);
      // Still on the menu: a quick add does not navigate anywhere.
      expect(find.text('What are you craving?'), findsOneWidget);
      expect(find.text('View cart'), findsOneWidget);
    });
  });

  group('the cart hands the checkout what the customer agreed to', () {
    journeyTest('the total on the cart is the total the order carries',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      );
      harness.checkout.order = placedOrder(id: 62, number: '62');
      await harness.pump(tester);

      await harness.openCartTab(tester);
      expect(find.text(r'$23.50'), findsWidgets);

      await harness.tapIn(tester, find.text('Go to checkout'));
      await harness.tapIn(tester, find.text('Place order'));

      // The figure the customer was shown, submitted as the one they agreed
      // to — the checkout's defence against a total that moved underneath
      // them is only as good as the number it carries over.
      expect(harness.checkout.drafts.single.expectedTotal, '2350');
    });

    journeyTest('the checkout summarises the same lines the cart listed',
        (tester) async {
      final harness = JourneyHarness(
        cart: FakeCartRepository(cart: cartFromFixture('cart_with_addons')),
      );
      await harness.pump(tester);

      await harness.openCartTab(tester);
      expect(find.text('Fresh Lemonade'), findsWidgets);
      expect(find.text('Margherita'), findsWidgets);

      await harness.tapIn(tester, find.text('Go to checkout'));

      // Both dishes again, with the add-ons still under the one that has
      // them: the checkout reads the same cart, not a re-fetched guess. The
      // summary names each line with its quantity, so `2× Fresh Lemonade`.
      expect(find.text(r'2× Fresh Lemonade'), findsOneWidget);
      expect(find.text(r'1× Margherita'), findsOneWidget);
      expect(find.textContaining('Medium 12"'), findsWidgets);
    });

    journeyTest('an empty cart offers no way through to the checkout',
        (tester) async {
      final harness = JourneyHarness();
      await harness.pump(tester);

      await harness.openCartTab(tester);

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Go to checkout'), findsNothing);
    });
  });
}

/// The running total, scoped to the dish screen's add button — the dish's own
/// price is on the page too, so a bare text finder would match either.
Finder priceOnButton(String amount) => find.descendant(
      of: find.byType(FilledButton),
      matching: find.text(amount),
    );

/// The + on a named dish's menu card.
Finder quickAddFor(String dish) => find
    .descendant(
      of: find.ancestor(
        of: find.text(dish),
        matching: find.byType(DishCard),
      ),
      matching: find.byType(QuickAddButton),
    )
    .first;

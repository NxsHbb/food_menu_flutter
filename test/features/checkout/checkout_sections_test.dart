import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/checkout/domain/checkout_config.dart';

import 'checkout_harness.dart';

void main() {
  group('CheckoutSections', () {
    test('a plugin that sends no sections draws everything', () {
      // A store on an older plugin, or one with the custom checkout off,
      // keeps the checkout the app already had.
      final sections = CheckoutSections.fromJson(const {});

      expect(sections.orderType, isTrue);
      expect(sections.yourLocation, isTrue);
      expect(sections.orderNotes, isTrue);
      expect(sections.tips, isTrue);
    });

    test('a half-written block only hides what it names', () {
      final sections = CheckoutSections.fromJson(const {'order_notes': false});

      expect(sections.orderNotes, isFalse);
      expect(sections.orderType, isTrue);
      expect(sections.yourLocation, isTrue);
      expect(sections.tips, isTrue);
    });
  });

  group('CheckoutTexts', () {
    test('absent is empty, so the app keeps its own wording', () {
      final texts = CheckoutTexts.fromJson(const {});

      expect(texts.heading, isEmpty);
      expect(texts.terms, isEmpty);
      expect(texts.placeOrder, isEmpty);
    });

    test('whitespace-only is empty too', () {
      // A store that cleared the field leaves a space behind often enough
      // that a blank heading would otherwise reach the screen.
      final texts = CheckoutTexts.fromJson(const {
        'heading': '   ',
        'terms': '\n',
        'place_order': ' ',
      });

      expect(texts.heading, isEmpty);
      expect(texts.terms, isEmpty);
      expect(texts.placeOrder, isEmpty);
    });
  });

  group('the sections a store switched off', () {
    testWidgets('draws all of them by default', (tester) async {
      final harness = CheckoutHarness();
      await harness.pump(tester);

      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Order notes'), findsOneWidget);
    });

    testWidgets('a hidden order type takes the switch, not the slots',
        (tester) async {
      final harness = CheckoutHarness()
        ..checkout.sectionsAnswer = const CheckoutSections(
          orderType: false,
          yourLocation: true,
          orderNotes: true,
          tips: true,
        );
      await harness.pump(tester);

      expect(find.text('Pickup'), findsNothing);
      expect(find.text('Delivery'), findsNothing);
      // The type still resolves and its times are still drawn.
      expect(find.textContaining('ASAP'), findsWidgets);
    });

    testWidgets('hidden order notes leave the rest of contact details',
        (tester) async {
      final harness = CheckoutHarness()
        ..checkout.sectionsAnswer = const CheckoutSections(
          orderType: true,
          yourLocation: true,
          orderNotes: false,
          tips: true,
        );
      await harness.pump(tester);

      expect(find.text('Order notes'), findsNothing);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
    });

    testWidgets('a hidden location keeps the delivery address', (tester) async {
      // `show_your_location` governs the pickup branch card only. The
      // delivery address is the app's single address surface, so nothing
      // hides it — see FINDINGS.
      final harness = CheckoutHarness()
        ..checkout.sectionsAnswer = const CheckoutSections(
          orderType: true,
          yourLocation: false,
          orderNotes: true,
          tips: true,
        );
      await harness.pump(tester);

      expect(find.text('Deliver to · Home'), findsOneWidget);
      expect(find.text('Pick up from'), findsNothing);
    });
  });

  group("the store's own words", () {
    testWidgets('the app speaks for itself when the store set nothing',
        (tester) async {
      final harness = CheckoutHarness();
      await harness.pump(tester);

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Place order'), findsOneWidget);
      expect(
        find.textContaining('you agree to our Terms & Conditions'),
        findsOneWidget,
      );
    });

    testWidgets('and the store speaks for itself when it has', (tester) async {
      final harness = CheckoutHarness()
        ..checkout.textsAnswer = const CheckoutTexts(
          heading: 'Almost there',
          terms: 'By ordering you accept our kitchen terms.',
          placeOrder: 'Send it',
        );
      await harness.pump(tester);

      expect(find.text('Almost there'), findsOneWidget);
      expect(find.text('Send it'), findsOneWidget);
      expect(
        find.text('By ordering you accept our kitchen terms.'),
        findsOneWidget,
      );
      // The app's own wording is gone, not sitting alongside.
      expect(find.text('Checkout'), findsNothing);
      expect(find.text('Place order'), findsNothing);
      expect(
        find.textContaining('you agree to our Terms & Conditions'),
        findsNothing,
      );
    });

    testWidgets('an entity-escaped sentence is decoded', (tester) async {
      // WordPress stores what the admin typed, entities and all.
      final harness = CheckoutHarness()
        ..checkout.textsAnswer = const CheckoutTexts(
          terms: 'See the kitchen&#8217;s terms.',
        );
      await harness.pump(tester);

      expect(find.text('See the kitchen’s terms.'), findsOneWidget);
    });
  });
}

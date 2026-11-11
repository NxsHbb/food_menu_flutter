import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/checkout/domain/checkout_field.dart';
import 'package:food_menu/src/features/checkout/presentation/widgets/checkout_fields_section.dart';

import 'checkout_harness.dart';

List<CheckoutField> _fields() => [
      CheckoutField.fromJson(const {
        'key': 'custom_0',
        'label': 'Apartment / buzzer',
        'type': 'text',
        'required': true,
      }),
      CheckoutField.fromJson(const {
        'key': 'custom_1',
        'label': 'Allergies',
        'type': 'select',
        'multiple': true,
        'options': ['Nuts', 'Dairy', 'Gluten'],
      }),
    ];

void main() {
  testWidgets('a store with no extra fields gets no section', (tester) async {
    final harness = CheckoutHarness();
    await harness.pump(tester);

    // No heading over nothing.
    expect(find.byType(CheckoutFieldsSection), findsOneWidget);
    expect(find.text('Additional information'), findsNothing);
  });

  testWidgets('draws the store own questions, in its own words',
      (tester) async {
    final harness = CheckoutHarness()..checkout.fieldsAnswer = _fields();
    await harness.pump(tester);

    expect(find.text('Additional information'), findsOneWidget);
    // Required is marked, optional is not.
    expect(find.text('Apartment / buzzer *'), findsOneWidget);
    expect(find.text('Allergies'), findsOneWidget);
    for (final option in ['Nuts', 'Dairy', 'Gluten']) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('a failed load costs the section, not the checkout',
      (tester) async {
    final harness = CheckoutHarness()
      ..checkout.failNextFields = StateError('no such route');
    await harness.pump(tester);

    // A store on an older plugin has no route at all. The checkout still
    // draws, and still places orders.
    expect(find.text('Additional information'), findsNothing);
    expect(find.text('Place order'), findsOneWidget);
  });

  testWidgets('an answered question reaches the order', (tester) async {
    final harness = CheckoutHarness()..checkout.fieldsAnswer = _fields();
    await harness.pump(tester);

    // The test account carries no phone, and the contact section requires
    // one — nothing to do with these fields, but it blocks the order.
    await tester.enterText(find.byType(TextFormField).at(1), '01555 111222');
    await tester.pumpAndSettle();

    // Scoped to the section rather than indexed: the checkout's own name,
    // phone and note inputs come first and their count is not this test's
    // business.
    await tester.enterText(
      find
          .descendant(
            of: find.byType(CheckoutFieldsSection),
            matching: find.byType(TextFormField),
          )
          .first,
      'Flat 3B',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gluten'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Place order'));
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    final extension = harness.checkout.lastBody['extensions']
        as Map<String, dynamic>;
    final ours = extension['food-menu-pro'] as Map<String, dynamic>;

    expect(ours['fmp_custom_fields'], {
      'custom_0': 'Flat 3B',
      'custom_1': ['Nuts', 'Gluten'],
    });
  });

  testWidgets('a required question blocks the order until answered',
      (tester) async {
    final harness = CheckoutHarness()..checkout.fieldsAnswer = _fields();
    await harness.pump(tester);

    await tester.ensureVisible(find.text('Place order'));
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    // The screen's own Form, so this errors in the same pass as the name and
    // the phone rather than through a mechanism of its own.
    expect(find.text('This is required'), findsOneWidget);
    expect(harness.checkout.drafts, isEmpty);
  });
}

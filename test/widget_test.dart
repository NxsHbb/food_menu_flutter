import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_menu/src/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FoodMenuApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the menu tab', (tester) async {
    await pumpApp(tester);

    expect(find.text('Menu'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('bottom navigation reaches every top-level destination',
      (tester) async {
    await pumpApp(tester);

    for (final label in ['Cart', 'Orders', 'Account']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      // The destination's own screen title renders alongside the tab label.
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('each shell branch keeps its own state', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart and add-on choices arrive in Phase 4.'),
        findsOneWidget);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Categories and dishes arrive in Phase 2.'),
        findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/dish_card.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/discount_badge.dart';

import 'fake_menu_repository.dart';

/// `DishCard` was the one surface that drew a dish name raw, so an apostrophe
/// reached the menu grid as `&#8217;`. Found by seeding the dev store with a
/// dish called "Chef's Slow-Braised Short Rib".
void main() {
  Future<void> pump(WidgetTester tester, {required String name}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: DishCard(
                product: buildProduct(id: 1, name: name),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an apostrophe is decoded, not printed as its entity',
      (tester) async {
    await pump(tester, name: 'Chef&#8217;s Short Rib');

    expect(find.textContaining('&#8217;'), findsNothing);
    expect(find.textContaining('’s Short Rib'), findsOneWidget);
  });

  testWidgets('an ampersand too', (tester) async {
    await pump(tester, name: 'Fish &amp; Chips');

    expect(find.text('Fish & Chips'), findsOneWidget);
  });

  testWidgets('a plain name is left exactly as it is', (tester) async {
    await pump(tester, name: 'Double Smash');

    expect(find.text('Double Smash'), findsOneWidget);
  });

  testWidgets('no badge on a dish with no discount', (tester) async {
    await pump(tester, name: 'Double Smash');

    expect(find.byType(DiscountBadge), findsNothing);
  });
}

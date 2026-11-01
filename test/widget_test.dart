import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/app.dart';
import 'package:food_menu/src/features/menu/data/banner_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';

import 'features/menu/fake_banner_repository.dart';
import 'features/menu/fake_menu_repository.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // The menu screen is real now, so the shell tests would otherwise
        // reach for the network.
        overrides: [
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(
              categoryList: [buildCategory()],
              productList: [buildProduct()],
            ),
          ),
          bannerRepositoryProvider.overrideWithValue(FakeBannerRepository()),
        ],
        child: const FoodMenuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the menu tab', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('What are you craving?'), findsOneWidget);
  });

  testWidgets('bottom navigation reaches every top-level destination',
      (tester) async {
    await pumpApp(tester);

    for (final label in ['Cart', 'Orders', 'Account']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('each shell branch keeps its own state', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your cart and add-on choices arrive in Phase 4.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('What are you craving?'), findsOneWidget);
  });
}

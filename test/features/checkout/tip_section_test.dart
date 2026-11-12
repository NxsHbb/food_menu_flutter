import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/checkout/presentation/widgets/tip_section.dart';

import '../cart/fake_cart_repository.dart';

void main() {
  Future<FakeCartRepository> pump(
    WidgetTester tester, {
    required Map<String, dynamic> tip,
    String screen = 'checkout',
  }) async {
    final cart = cartFromFixture('cart_with_item');
    final withTip = Cart.fromJson({
      'items': const <dynamic>[],
      'items_count': 1,
      'totals': {
        'total_price': '1300',
        'currency_code': 'USD',
        'currency_minor_unit': 2,
        'currency_decimal_separator': '.',
        'currency_thousand_separator': ',',
        'currency_prefix': r'$',
        'currency_suffix': '',
      },
      'extensions': {
        'food-menu-pro': {'tip': tip},
      },
    });
    expect(cart.itemsCount, greaterThan(0));

    final repo = FakeCartRepository(cart: withTip);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cartRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 400, child: TipSection(screen: screen)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('a store with tipping off shows nothing', (tester) async {
    await pump(tester, tip: {'enabled': false, 'allow': <String>[]});

    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('Add'), findsNothing);
  });

  testWidgets('the store that asks only on the cart is not asked here',
      (tester) async {
    await pump(tester, tip: {
      'enabled': true,
      'allow': ['fixed'],
      'where': 'cart',
    });

    expect(find.text('Add'), findsNothing);
  });

  testWidgets("the store's own prompt is the heading", (tester) async {
    await pump(tester, tip: {
      'enabled': true,
      'allow': ['fixed'],
      'where': 'both',
      'heading': 'Look after the kitchen?',
    });

    expect(find.text('Look after the kitchen?'), findsOneWidget);
  });

  testWidgets('one allowed kind draws no toggle to choose between',
      (tester) async {
    await pump(tester, tip: {
      'enabled': true,
      'allow': ['percentage'],
      'where': 'both',
    });

    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('a fixed amount is sent in minor units', (tester) async {
    final repo = await pump(tester, tip: {
      'enabled': true,
      'allow': ['fixed'],
      'where': 'both',
    });

    await tester.enterText(find.byType(TextField), '2.50');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(repo.tipType, 'fixed');
    expect(repo.tipAmount, 250);
  });

  testWidgets('a percentage is sent as whole percent', (tester) async {
    final repo = await pump(tester, tip: {
      'enabled': true,
      'allow': ['percentage'],
      'where': 'both',
    });

    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(repo.tipType, 'percentage');
    expect(repo.tipAmount, 15);
  });

  testWidgets('removing sends zero, which is the plugin\'s own "remove"',
      (tester) async {
    final repo = await pump(tester, tip: {
      'enabled': true,
      'allow': ['percentage'],
      'where': 'both',
      'type': 'percentage',
      'percentage': 15,
      'fixed': '0',
    });

    expect(find.text('15% tip added.'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(repo.tipAmount, 0);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/menu/data/addons_repository.dart';
import 'package:food_menu/src/features/menu/data/menu_repository.dart';
import 'package:food_menu/src/features/menu/presentation/menu_list_screen.dart';
import 'package:food_menu/src/features/menu/presentation/product_detail_screen.dart';
import 'package:food_menu/src/features/menu/presentation/widgets/variation_picker.dart';
import 'package:go_router/go_router.dart';

import '../cart/fake_cart_repository.dart';
import 'fake_addons_repository.dart';
import 'fake_menu_repository.dart';

Product _fixture(String name) {
  final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
  return Product.fromJson(json as Map<String, dynamic>);
}

void main() {
  late FakeCartRepository cartRepo;
  late FakeMenuRepository menuRepo;

  /// Behind a real router, because adding closes the dish — so the test has
  /// somewhere to close to.
  Future<void> pump(WidgetTester tester) async {
    cartRepo = FakeCartRepository();
    // Answers per id, so asking for the chosen variation returns the
    // variation and not the parent again.
    menuRepo = FakeMenuRepository(
      productList: [_fixture('product_variable'), _fixture('product_variation')],
    );

    final router = GoRouter(
      initialLocation: '/dish',
      routes: [
        GoRoute(
          path: '/',
          name: MenuListScreen.routeName,
          builder: (_, _) => const Scaffold(body: Text('menu')),
        ),
        GoRoute(
          path: '/dish',
          builder: (_, _) => const ProductDetailScreen(productId: 27),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuRepositoryProvider.overrideWithValue(menuRepo),
          addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
          cartRepositoryProvider.overrideWithValue(cartRepo),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// `ensureVisible` rather than a scroll: the bottom bar overlaps the list,
  /// so a term can be on screen and still not hit-testable.
  Future<void> tapTerm(WidgetTester tester, String term) async {
    await tester.ensureVisible(find.text(term));
    await tester.pumpAndSettle();
    await tester.tap(find.text(term));
    await tester.pumpAndSettle();
  }

  group('the picker', () {
    testWidgets('asks the store own question, in the store own words',
        (tester) async {
      await pump(tester);

      expect(find.byType(VariationPicker), findsOneWidget);
      // "Size", not "pa_size" and not a label this app invented.
      expect(find.text('Size'), findsOneWidget);
      for (final term in ['Small', 'Medium', 'Large']) {
        expect(find.text(term), findsOneWidget);
      }
    });

    testWidgets('a simple dish has no picker at all', (tester) async {
      menuRepo = FakeMenuRepository()..single = _fixture('product_simple');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            menuRepositoryProvider.overrideWithValue(menuRepo),
            addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProductDetailScreen(productId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VariationPicker), findsNothing);
    });
  });

  group('the price', () {
    testWidgets('is the range until a size is chosen', (tester) async {
      await pump(tester);

      expect(find.text('from'), findsOneWidget);
      expect(find.text(r'$8.50'), findsOneWidget);
      expect(find.text('Choose options'), findsOneWidget);
    });

    testWidgets('becomes the chosen variation own price', (tester) async {
      await pump(tester);
      await tapTerm(tester, 'Medium');

      // 1150 minor units, read back from the variation rather than guessed
      // from the parent's range.
      expect(find.textContaining(r'$11.50'), findsWidgets);
      expect(find.text('Choose options'), findsNothing);
    });
  });

  group('adding', () {
    testWidgets('refuses, by name, until a size is chosen', (tester) async {
      await pump(tester);

      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      expect(find.text('Choose size first.'), findsOneWidget);
      expect(cartRepo.calls.where((c) => c.startsWith('add')), isEmpty);
    });

    testWidgets('sends the parent id and the chosen attribute',
        (tester) async {
      await pump(tester);
      // Medium, because the fake only carries that variation's own product —
      // the others would fall back to the parent and its price range.
      await tapTerm(tester, 'Medium');

      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      // The parent's id: the server resolves the variation from the
      // attributes and answers with a line under the variation's own.
      // `calls` also holds the cart's own first read.
      expect(
        cartRepo.calls.where((c) => c.startsWith('add')).single,
        'add 27 x1',
      );
      expect(cartRepo.variationPayloads.single, [
        {'attribute': 'Size', 'value': 'Medium'},
      ]);
    });

    testWidgets('a combination the store never made is named, not posted',
        (tester) async {
      // Every variation removed, so a complete choice resolves to nothing.
      final json = jsonDecode(
        File('test/fixtures/product_variable.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      json['variations'] = <Object>[];

      cartRepo = FakeCartRepository();
      menuRepo = FakeMenuRepository()..single = Product.fromJson(json);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            menuRepositoryProvider.overrideWithValue(menuRepo),
            addonsRepositoryProvider.overrideWithValue(FakeAddonsRepository()),
            cartRepositoryProvider.overrideWithValue(cartRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProductDetailScreen(productId: 27),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapTerm(tester, 'Small');

      // The button still reads "Choose options": everything is answered and
      // nothing resolves, which is a choice the customer cannot complete.
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      // Better than letting the server answer "no such variation", which
      // reads as a fault rather than a gap in the menu.
      expect(find.text('That combination is not available.'), findsOneWidget);
      expect(cartRepo.calls.where((c) => c.startsWith('add')), isEmpty);
    });
  });
}

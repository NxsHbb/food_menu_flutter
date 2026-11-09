import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_repository.dart';
import 'package:food_menu/src/features/wishlist/presentation/widgets/wishlist_row.dart';
import 'package:food_menu/src/features/wishlist/presentation/wishlist_screen.dart';

import '../auth/fake_auth_repository.dart';
import '../menu/fake_menu_repository.dart';
import 'fake_wishlist_repository.dart';

void main() {
  Future<ProviderContainer> pumpWishlist(
    WidgetTester tester, {
    required FakeWishlistRepository repo,
    bool signedIn = true,
    ThemeData? theme,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        wishlistRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: const WishlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  final latte = buildProduct(id: 26, name: 'Iced Latte', price: '450');
  final lemonade = buildProduct(id: 25, name: 'Fresh Lemonade', price: '350');

  testWidgets('lists the saved dishes, newest first', (tester) async {
    await pumpWishlist(
      tester,
      repo: FakeWishlistRepository(saved: [lemonade, latte]),
    );

    expect(find.byType(WishlistRow), findsExactly(2));
    expect(find.text('Fresh Lemonade'), findsOne);
    expect(find.text('Iced Latte'), findsOne);

    // Order matters: the server returns newest first and the screen keeps it.
    final rows = tester.widgetList<WishlistRow>(find.byType(WishlistRow));
    expect(rows.map((r) => r.product.id), [25, 26]);
  });

  testWidgets('shows the price', (tester) async {
    await pumpWishlist(tester, repo: FakeWishlistRepository(saved: [latte]));

    expect(find.text(r'$4.50'), findsOne);
  });

  testWidgets('an empty wishlist explains how to fill it', (tester) async {
    await pumpWishlist(tester, repo: FakeWishlistRepository());

    expect(find.text('Tap the heart on any dish to save it here.'), findsOne);
    expect(find.byType(WishlistRow), findsNothing);
  });

  testWidgets('signed out, it invites the customer to sign in',
      (tester) async {
    final repo = FakeWishlistRepository(saved: [latte]);
    await pumpWishlist(tester, repo: repo, signedIn: false);

    expect(find.text('Sign in'), findsOne);
    expect(find.byType(WishlistRow), findsNothing);
    // The wishlist is account-scoped, so there is nothing to ask for.
    expect(repo.calls, isEmpty);
  });

  testWidgets('unfavouriting from the list removes the row', (tester) async {
    final repo = FakeWishlistRepository(saved: [latte, lemonade]);
    await pumpWishlist(tester, repo: repo);

    expect(find.byType(WishlistRow), findsExactly(2));

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Iced Latte'),
          matching: find.byType(WishlistRow),
        ),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WishlistRow), findsOne);
    expect(find.text('Iced Latte'), findsNothing);
    expect(repo.calls.last, (call: 'remove', productId: 26));
  });

  testWidgets('emptying the list falls through to the empty state',
      (tester) async {
    await pumpWishlist(tester, repo: FakeWishlistRepository(saved: [latte]));

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tap the heart on any dish to save it here.'), findsOne);
  });

  testWidgets('a failed load offers a retry that reloads', (tester) async {
    final repo = FakeWishlistRepository()
      ..loadError = const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server.',
      );
    await pumpWishlist(tester, repo: repo);

    expect(find.text('Could not reach the server.'), findsOne);

    repo
      ..loadError = null
      ..saved.add(latte);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(WishlistRow), findsOne);
    expect(find.text('Iced Latte'), findsOne);
  });

  testWidgets('renders in dark mode without overflow', (tester) async {
    await pumpWishlist(
      tester,
      repo: FakeWishlistRepository(saved: [latte, lemonade]),
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(WishlistRow), findsExactly(2));
  });

  testWidgets('a long dish name does not overflow its row', (tester) async {
    await pumpWishlist(
      tester,
      repo: FakeWishlistRepository(
        saved: [
          buildProduct(
            id: 99,
            name: 'Slow-roasted aubergine with pomegranate molasses, '
                'whipped feta and toasted pine nuts',
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

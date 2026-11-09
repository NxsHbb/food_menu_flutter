import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/presentation/login_screen.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_repository.dart';
import 'package:food_menu/src/features/wishlist/presentation/widgets/wishlist_heart.dart';
import 'package:go_router/go_router.dart';

import '../auth/fake_auth_repository.dart';
import '../menu/fake_menu_repository.dart';
import 'fake_wishlist_repository.dart';

void main() {
  final latte = buildProduct(id: 26, name: 'Iced Latte', price: '450');

  /// The heart inside a router, since tapping it while signed out navigates.
  Future<void> pumpHeart(
    WidgetTester tester, {
    required FakeWishlistRepository repo,
    bool signedIn = true,
    HeartStyle style = HeartStyle.onImage,
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

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: WishlistHeart(product: latte, style: style),
            ),
          ),
        ),
        GoRoute(
          path: LoginScreen.routePath,
          name: LoginScreen.routeName,
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a dish that is not saved shows an outline heart',
      (tester) async {
    await pumpHeart(tester, repo: FakeWishlistRepository());

    expect(find.byIcon(Icons.favorite_border_rounded), findsOne);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('a saved dish shows a filled heart', (tester) async {
    await pumpHeart(tester, repo: FakeWishlistRepository(saved: [latte]));

    expect(find.byIcon(Icons.favorite_rounded), findsOne);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });

  testWidgets('tapping fills it and saves the dish', (tester) async {
    final repo = FakeWishlistRepository()..catalogue[26] = latte;
    await pumpHeart(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOne);
    expect(repo.calls.last, (call: 'add', productId: 26));
  });

  testWidgets('tapping a filled heart unsaves the dish', (tester) async {
    final repo = FakeWishlistRepository(saved: [latte]);
    await pumpHeart(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOne);
    expect(repo.calls.last, (call: 'remove', productId: 26));
  });

  testWidgets('signed out, tapping opens sign-in instead of calling the API',
      (tester) async {
    final repo = FakeWishlistRepository();
    await pumpHeart(tester, repo: repo, signedIn: false);

    // Shown, not hidden: a signed-out customer should still see that dishes
    // can be saved.
    expect(find.byIcon(Icons.favorite_border_rounded), findsOne);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOne);
    expect(repo.calls, isEmpty);
  });

  testWidgets('a failed save reverts the heart and says so', (tester) async {
    final repo = FakeWishlistRepository()
      ..writeError = const ApiException(
        failure: ApiFailure.network,
        message: 'Offline',
      );
    await pumpHeart(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOne);
    expect(find.text('Could not save that dish. Please try again.'), findsOne);
  });

  testWidgets('a full wishlist shows the wording the server sent',
      (tester) async {
    final repo = FakeWishlistRepository()
      ..writeError = const ApiException(
        failure: ApiFailure.http,
        message: 'Your wishlist is full. You can save up to 100 dishes.',
        statusCode: 409,
        code: 'fmp_app_wishlist_full',
      );
    await pumpHeart(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    // Passed through, because the cap is a number only the server knows.
    expect(
      find.text('Your wishlist is full. You can save up to 100 dishes.'),
      findsOne,
    );
  });

  testWidgets('a 401 asks the customer to sign in again', (tester) async {
    final repo = FakeWishlistRepository()
      ..writeError = const ApiException(
        failure: ApiFailure.http,
        message: 'You must be signed in to do that.',
        statusCode: 401,
      );
    await pumpHeart(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    // Not the server's wording: "You must be signed in" reads as an app bug
    // to somebody who is looking at a signed-in screen.
    expect(find.text('Please sign in again to save dishes.'), findsOne);
  });

  testWidgets('the tinted style is a 38px square, per the design',
      (tester) async {
    await pumpHeart(
      tester,
      repo: FakeWishlistRepository(saved: [latte]),
      style: HeartStyle.tinted,
    );

    final size = tester.getSize(find.byType(WishlistHeart));
    expect(size.width, 38);
    expect(size.height, 38);
  });

  testWidgets('it is labelled for screen readers', (tester) async {
    await pumpHeart(tester, repo: FakeWishlistRepository());

    expect(
      find.bySemanticsLabel('Save Iced Latte to wishlist'),
      findsOne,
    );
  });
}

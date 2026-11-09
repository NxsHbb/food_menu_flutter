import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/account/data/profile_repository.dart';
import 'package:food_menu/src/features/address/data/address_repository.dart';
import 'package:food_menu/src/features/account/presentation/account_screen.dart';
import 'package:food_menu/src/features/account/presentation/edit_profile_screen.dart';
import 'package:food_menu/src/features/account/presentation/widgets/account_row.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/presentation/login_screen.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_repository.dart';
import 'package:food_menu/src/features/wishlist/presentation/wishlist_screen.dart';
import 'package:go_router/go_router.dart';

import '../auth/fake_auth_repository.dart';
import '../menu/fake_menu_repository.dart';
import '../address/fake_address_repository.dart';
import '../wishlist/fake_wishlist_repository.dart';
import 'fake_profile_repository.dart';

void main() {
  Future<ProviderContainer> pumpAccount(
    WidgetTester tester, {
    required FakeAuthRepository repo,
    bool signedIn = false,
    FakeWishlistRepository? wishlist,
    FakeAddressRepository? addresses,
    ThemeData? theme,
  }) async {
    // The reported-device width. The account header is a row of avatar, two
    // lines of text and a button, which is exactly the shape that only
    // overflows on a narrow screen.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        wishlistRepositoryProvider
            .overrideWithValue(wishlist ?? FakeWishlistRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        addressRepositoryProvider
            .overrideWithValue(addresses ?? FakeAddressRepository()),
      ],
    );
    addTearDown(container.dispose);

    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
    }

    final router = GoRouter(
      initialLocation: AccountScreen.routePath,
      routes: [
        GoRoute(
          path: AccountScreen.routePath,
          name: AccountScreen.routeName,
          builder: (context, state) => const AccountScreen(),
          routes: [
            GoRoute(
              path: WishlistScreen.routePath,
              name: WishlistScreen.routeName,
              builder: (context, state) => const WishlistScreen(),
            ),
            GoRoute(
              path: EditProfileScreen.routePath,
              name: EditProfileScreen.routeName,
              builder: (context, state) => const EditProfileScreen(),
            ),
          ],
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
          theme: theme ?? AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('signed out, invites the customer to sign in', (tester) async {
    await pumpAccount(tester, repo: FakeAuthRepository());

    expect(find.text('Sign in'), findsOne);
    expect(find.text('Log out'), findsNothing);
    expect(find.byType(AccountRow), findsNothing);
  });

  testWidgets('signed in, the header shows who it is', (tester) async {
    await pumpAccount(tester, repo: FakeAuthRepository(), signedIn: true);

    expect(find.text('Test Customer'), findsOne);
    expect(find.text('customer@foodmenu.test'), findsOne);
    expect(find.text('TC'), findsOne);
    expect(find.text('Edit'), findsOne);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('lists only the rows that lead somewhere', (tester) async {
    await pumpAccount(tester, repo: FakeAuthRepository(), signedIn: true);

    expect(find.text('My orders'), findsOne);
    expect(find.text('Wishlist'), findsOne);
    expect(find.text('Saved addresses'), findsOne);
    // Task 3.11's pair, in their own card.
    expect(find.text('Change password'), findsOne);
    expect(find.text('Change email'), findsOne);

    // The design's other three have no backend in v1 — rendering them would
    // mean inventing "Visa 4242" and a help centre. See the class docblock.
    expect(find.text('Payment methods'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Help & support'), findsNothing);
    expect(find.byType(AccountRow), findsExactly(5));
  });

  testWidgets('the wishlist row carries its real count', (tester) async {
    await pumpAccount(
      tester,
      repo: FakeAuthRepository(),
      signedIn: true,
      wishlist: FakeWishlistRepository(
        saved: [buildProduct(id: 1), buildProduct(id: 2)],
      ),
    );

    final row = tester.widget<AccountRow>(
      find.ancestor(
        of: find.text('Wishlist'),
        matching: find.byType(AccountRow),
      ),
    );
    expect(row.value, '2');
  });

  testWidgets('the addresses row carries its real count', (tester) async {
    await pumpAccount(
      tester,
      repo: FakeAuthRepository(),
      signedIn: true,
      addresses: FakeAddressRepository(
        book: [buildAddress(id: 'a'), buildAddress(id: 'b')],
      ),
    );

    final row = tester.widget<AccountRow>(
      find.ancestor(
        of: find.text('Saved addresses'),
        matching: find.byType(AccountRow),
      ),
    );
    expect(row.value, '2');
  });

  testWidgets('My orders carries no count, having no endpoint yet',
      (tester) async {
    await pumpAccount(tester, repo: FakeAuthRepository(), signedIn: true);

    final row = tester.widget<AccountRow>(
      find.ancestor(
        of: find.text('My orders'),
        matching: find.byType(AccountRow),
      ),
    );
    // A zero here would read as "you have never ordered", which we do not
    // know. Task 7.1 supplies the real number.
    expect(row.value, isNull);
  });

  testWidgets('Edit opens the profile form', (tester) async {
    await pumpAccount(tester, repo: FakeAuthRepository(), signedIn: true);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOne);
  });

  testWidgets('the wishlist row opens the wishlist', (tester) async {
    await pumpAccount(tester, repo: FakeAuthRepository(), signedIn: true);

    await tester.tap(find.text('Wishlist'));
    await tester.pumpAndSettle();

    expect(find.byType(WishlistScreen), findsOne);
  });

  testWidgets('a saved name shows on the header straight away',
      (tester) async {
    final container =
        await pumpAccount(tester, repo: FakeAuthRepository(), signedIn: true);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Habibur');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // Back on the account screen, with the new name — the whole point of
    // writing the result back into the session.
    expect(find.text('Habibur Customer'), findsOne);
    expect(
      container.read(currentSessionProvider)?.user.firstName,
      'Habibur',
    );
  });

  testWidgets('logging out returns it to the signed-out state',
      (tester) async {
    final repo = FakeAuthRepository();
    await pumpAccount(tester, repo: repo, signedIn: true);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOne);
    expect(repo.calls.last['call'], 'logout');
  });

  testWidgets('a long name and email do not overflow the header',
      (tester) async {
    await pumpAccount(
      tester,
      repo: FakeAuthRepository(
        session: sessionFor(
          firstName: 'Bartholomew',
          lastName: 'Featherstonehaugh-Cholmondeley',
          email: 'bartholomew.featherstonehaugh@a-very-long-domain.example',
        ),
      ),
      signedIn: true,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Edit'), findsOne);
  });

  testWidgets('renders in dark mode without overflow', (tester) async {
    await pumpAccount(
      tester,
      repo: FakeAuthRepository(),
      signedIn: true,
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AccountRow), findsExactly(5));
  });
}

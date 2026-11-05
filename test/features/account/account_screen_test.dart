import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/account/presentation/account_screen.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';

import '../auth/fake_auth_repository.dart';

void main() {
  Future<ProviderContainer> pumpAccount(
    WidgetTester tester, {
    required FakeAuthRepository repo,
    bool signedIn = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
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
          theme: AppTheme.light(),
          home: const AccountScreen(),
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
  });

  testWidgets('signed in, shows who it is', (tester) async {
    await pumpAccount(tester, repo: FakeAuthRepository(), signedIn: true);

    expect(find.text('Test Customer'), findsOne);
    expect(find.text('customer@foodmenu.test'), findsOne);
    expect(find.text('TC'), findsOne);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('logging out returns it to the signed-out state', (tester) async {
    final repo = FakeAuthRepository();
    await pumpAccount(tester, repo: repo, signedIn: true);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOne);
    expect(repo.calls.last['call'], 'logout');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/account/presentation/change_email_screen.dart';
import 'package:food_menu/src/features/account/presentation/change_password_screen.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/presentation/forgot_password_screen.dart';
import 'package:food_menu/src/features/auth/presentation/reset_password_screen.dart';
import 'package:go_router/go_router.dart';

import 'fake_auth_repository.dart';

void main() {
  Future<({ProviderContainer container, FakeTokenStore store})> pump(
    WidgetTester tester,
    Widget screen, {
    required FakeAuthRepository repo,
    bool signedIn = false,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final store = FakeTokenStore();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
      repo.calls.clear();
    }

    // The screen under test is a *child* route, so there is something
    // beneath it to pop back to — these screens pop themselves on success,
    // and at the router root that pops the last page off the stack.
    final router = GoRouter(
      initialLocation: '/screen',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Behind'))),
          routes: [
            GoRoute(path: 'screen', builder: (context, state) => screen),
            GoRoute(
              path: 'reset',
              name: ResetPasswordScreen.routeName,
              builder: (context, state) => ResetPasswordScreen(
                email: state.uri.queryParameters['email'] ?? '',
              ),
            ),
          ],
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
    return (container: container, store: store);
  }

  group('forgot password', () {
    testWidgets('asks the server and moves on to the code screen',
        (tester) async {
      final repo = FakeAuthRepository();
      await pump(
        tester,
        const ForgotPasswordScreen(email: 'customer@foodmenu.test'),
        repo: repo,
      );

      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();

      expect(repo.calls.single['call'], 'forgot_password');
      expect(find.byType(ResetPasswordScreen), findsOne);
    });

    testWidgets('moves on even for an address with no account',
        (tester) async {
      // The server will not say whether the address is registered, and a
      // screen that only advanced for real customers would leak exactly
      // what the server is refusing to.
      final repo = FakeAuthRepository();
      await pump(
        tester,
        const ForgotPasswordScreen(email: 'nobody@nowhere.test'),
        repo: repo,
      );

      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOne);
    });

    testWidgets('will not submit a malformed address', (tester) async {
      final repo = FakeAuthRepository();
      await pump(tester, const ForgotPasswordScreen(email: 'nope'), repo: repo);

      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();

      expect(find.text('That does not look like an email address.'), findsOne);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a rate limit is reported rather than swallowed',
        (tester) async {
      final repo = FakeAuthRepository()
        ..securityError = const ApiException(
          failure: ApiFailure.http,
          message: 'Too many requests. Please try again in 42 minutes.',
          statusCode: 429,
        );
      await pump(
        tester,
        const ForgotPasswordScreen(email: 'customer@foodmenu.test'),
        repo: repo,
      );

      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Too many requests. Please try again in 42 minutes.'),
        findsOne,
      );
      expect(find.byType(ResetPasswordScreen), findsNothing);
    });
  });

  group('reset password', () {
    Future<({ProviderContainer container, FakeTokenStore store})> pumpReset(
      WidgetTester tester,
      FakeAuthRepository repo,
    ) {
      return pump(
        tester,
        const ResetPasswordScreen(email: 'customer@foodmenu.test'),
        repo: repo,
      );
    }

    testWidgets('signs the customer in on success', (tester) async {
      final repo = FakeAuthRepository();
      final result = await pumpReset(tester, repo);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(find.byType(TextFormField).at(1), 'Newpass@2020');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();

      expect(
        result.container.read(currentSessionProvider)?.user.email,
        'customer@foodmenu.test',
      );
      // Persisted, or the reset would not survive a restart.
      expect(result.store.calls, contains('write'));
    });

    testWidgets('rejects a code that is not six digits', (tester) async {
      final repo = FakeAuthRepository();
      await pumpReset(tester, repo);

      await tester.enterText(find.byType(TextFormField).at(0), '12ab');
      await tester.enterText(find.byType(TextFormField).at(1), 'Newpass@2020');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();

      expect(find.text('The code is six digits.'), findsOne);
      expect(repo.calls, isEmpty);
    });

    testWidgets('rejects a short password before the round trip',
        (tester) async {
      final repo = FakeAuthRepository();
      await pumpReset(tester, repo);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters.'), findsOne);
      expect(repo.calls, isEmpty);
    });

    testWidgets('shows the server wording for a bad code', (tester) async {
      final repo = FakeAuthRepository()
        ..securityError = const ApiException(
          failure: ApiFailure.http,
          message:
              'That code is not valid, or it has expired. Please request a new one.',
          statusCode: 400,
          code: 'fmp_app_invalid_reset_code',
        );
      final result = await pumpReset(tester, repo);

      await tester.enterText(find.byType(TextFormField).at(0), '000000');
      await tester.enterText(find.byType(TextFormField).at(1), 'Newpass@2020');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();

      expect(find.textContaining('That code is not valid'), findsOne);
      expect(result.container.read(currentSessionProvider), isNull);
    });

    testWidgets('can ask for another code', (tester) async {
      final repo = FakeAuthRepository();
      await pumpReset(tester, repo);

      await tester.tap(find.text('Send another code'));
      await tester.pumpAndSettle();

      expect(repo.calls.single['call'], 'forgot_password');
      expect(find.text('Code sent again'), findsOne);
    });

    testWidgets('a corrected field clears its error without resubmitting',
        (tester) async {
      // Found on the device: the message stayed on screen after the code was
      // fixed, until the next submit said otherwise.
      final repo = FakeAuthRepository();
      await pumpReset(tester, repo);

      await tester.enterText(find.byType(TextFormField).at(0), '1234');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();
      expect(find.text('The code is six digits.'), findsOne);

      await tester.enterText(find.byType(TextFormField).at(0), '123456');
      await tester.pumpAndSettle();

      expect(find.text('The code is six digits.'), findsNothing);
    });

    testWidgets('editing clears a server error it no longer describes',
        (tester) async {
      final repo = FakeAuthRepository()
        ..securityError = const ApiException(
          failure: ApiFailure.http,
          message: 'That code is not valid, or it has expired.',
          statusCode: 400,
          code: 'fmp_app_invalid_reset_code',
        );
      await pumpReset(tester, repo);

      await tester.enterText(find.byType(TextFormField).at(0), '000000');
      await tester.enterText(find.byType(TextFormField).at(1), 'Newpass@2020');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('That code is not valid'), findsOne);

      await tester.enterText(find.byType(TextFormField).at(0), '111111');
      await tester.pumpAndSettle();

      expect(find.textContaining('That code is not valid'), findsNothing);
    });

    testWidgets('says the reset signs you out elsewhere', (tester) async {
      await pumpReset(tester, FakeAuthRepository());

      expect(
        find.text('Setting a new password signs you out everywhere else.'),
        findsOne,
      );
    });
  });

  group('change password', () {
    testWidgets('adopts the session the server hands back', (tester) async {
      // The server revokes every session on success, so the token in hand is
      // already dead. Failing to adopt the replacement signs the customer out
      // on their next request — the one bug this screen can really make.
      final repo = FakeAuthRepository();
      final result = await pump(
        tester,
        const ChangePasswordScreen(),
        repo: repo,
        signedIn: true,
      );

      final before =
          result.container.read(currentSessionProvider)!.tokens.accessToken;

      await tester.enterText(find.byType(TextFormField).at(0), 'Current@2020');
      await tester.enterText(find.byType(TextFormField).at(1), 'Newpass@2020');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      final after =
          result.container.read(currentSessionProvider)!.tokens.accessToken;

      expect(after, isNot(before));
      expect(after, endsWith('_reissued'));
      expect(result.store.stored?.tokens.accessToken, after);
    });

    testWidgets('puts a wrong current password on its own field',
        (tester) async {
      final repo = FakeAuthRepository()
        ..securityError = const ApiException(
          failure: ApiFailure.http,
          message: 'That is not your current password.',
          statusCode: 403,
          code: 'fmp_app_incorrect_password',
        );
      await pump(
        tester,
        const ChangePasswordScreen(),
        repo: repo,
        signedIn: true,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'wrong');
      await tester.enterText(find.byType(TextFormField).at(1), 'Newpass@2020');
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      expect(find.text('That is not your current password.'), findsOne);
    });

    testWidgets('will not submit an empty form', (tester) async {
      final repo = FakeAuthRepository();
      await pump(
        tester,
        const ChangePasswordScreen(),
        repo: repo,
        signedIn: true,
      );

      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your current password.'), findsOne);
      expect(repo.calls, isEmpty);
    });
  });

  group('change email', () {
    testWidgets('requires the address twice', (tester) async {
      // Nothing is sent to the new address to prove it exists, so a typo
      // would lock the customer out of an address they cannot reclaim.
      final repo = FakeAuthRepository();
      await pump(
        tester,
        const ChangeEmailScreen(),
        repo: repo,
        signedIn: true,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'new@mail.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'nwe@mail.test');
      await tester.enterText(find.byType(TextFormField).at(2), 'Current@2020');
      await tester.tap(find.text('Update email'));
      await tester.pumpAndSettle();

      expect(find.text('The two addresses do not match.'), findsOne);
      expect(repo.calls, isEmpty);
    });

    testWidgets('changes the address and adopts the new session',
        (tester) async {
      final repo = FakeAuthRepository();
      final result = await pump(
        tester,
        const ChangeEmailScreen(),
        repo: repo,
        signedIn: true,
      );

      for (final (index, value) in [
        'new@mail.test',
        'new@mail.test',
        'Current@2020',
      ].indexed) {
        await tester.enterText(find.byType(TextFormField).at(index), value);
      }
      await tester.tap(find.text('Update email'));
      await tester.pumpAndSettle();

      final session = result.container.read(currentSessionProvider)!;
      expect(session.user.email, 'new@mail.test');
      expect(session.tokens.accessToken, endsWith('_reissued'));
    });

    testWidgets('an address already in use lands on the email field',
        (tester) async {
      final repo = FakeAuthRepository()
        ..securityError = const ApiException(
          failure: ApiFailure.http,
          message: 'That email address is already in use.',
          statusCode: 409,
          code: 'fmp_app_email_exists',
        );
      await pump(
        tester,
        const ChangeEmailScreen(),
        repo: repo,
        signedIn: true,
      );

      for (final (index, value) in [
        'taken@mail.test',
        'taken@mail.test',
        'Current@2020',
      ].indexed) {
        await tester.enterText(find.byType(TextFormField).at(index), value);
      }
      await tester.tap(find.text('Update email'));
      await tester.pumpAndSettle();

      expect(find.text('That email address is already in use.'), findsOne);
    });

    testWidgets('warns that nothing is sent to the new address',
        (tester) async {
      await pump(
        tester,
        const ChangeEmailScreen(),
        repo: FakeAuthRepository(),
        signedIn: true,
      );

      expect(
        find.textContaining('No confirmation is sent to the new address'),
        findsOne,
      );
    });

    testWidgets('renders in dark mode without overflow', (tester) async {
      await pump(
        tester,
        const ChangeEmailScreen(),
        repo: FakeAuthRepository(),
        signedIn: true,
        theme: AppTheme.dark(),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

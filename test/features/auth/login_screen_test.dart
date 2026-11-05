import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/presentation/login_screen.dart';

import 'fake_auth_repository.dart';

void main() {
  Future<ProviderContainer> pumpLogin(
    WidgetTester tester,
    FakeAuthRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> fill(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
  }

  testWidgets('signs in and reports success to whoever pushed the screen',
      (tester) async {
    final repo = FakeAuthRepository();
    final container = await pumpLogin(tester, repo);

    await fill(tester, 'customer@foodmenu.test', 'Customer@2020##');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(container.read(currentSessionProvider)?.user.email,
        'customer@foodmenu.test');
    expect(repo.calls.single['username'], 'customer@foodmenu.test');
  });

  testWidgets('will not submit an empty form', (tester) async {
    final repo = FakeAuthRepository();
    await pumpLogin(tester, repo);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.text('Enter your email address.'), findsOne);
    expect(find.text('Enter your password.'), findsOne);
  });

  testWidgets('shows the server message on a rejected sign-in', (tester) async {
    final repo = FakeAuthRepository(
      loginError: const ApiException(
        failure: ApiFailure.http,
        statusCode: 401,
        code: 'fmp_app_invalid_credentials',
        message: 'That email address and password do not match an account.',
      ),
    );
    final container = await pumpLogin(tester, repo);

    await fill(tester, 'customer@foodmenu.test', 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('That email address and password do not match an account.'),
      findsOne,
    );
    expect(container.read(currentSessionProvider), isNull);
  });

  testWidgets('a rate limit says how long to wait and offers no instant retry',
      (tester) async {
    final repo = FakeAuthRepository(
      loginError: const ApiException(
        failure: ApiFailure.http,
        statusCode: 429,
        code: 'fmp_app_too_many_requests',
        message: 'Too many attempts. Please wait a moment and try again.',
        retryAfter: Duration(seconds: 899),
      ),
    );
    await pumpLogin(tester, repo);

    await fill(tester, 'customer@foodmenu.test', 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Try again in 14 minutes.'), findsOne);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a network failure does offer a retry', (tester) async {
    final repo = FakeAuthRepository(
      loginError: const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server. Check your connection.',
      ),
    );
    await pumpLogin(tester, repo);

    await fill(tester, 'customer@foodmenu.test', 'Customer@2020##');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOne);

    // Retrying from the banner re-submits rather than just clearing it.
    repo.loginError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repo.calls.length, 2);
  });

  testWidgets('the button is disabled while a sign-in is in flight',
      (tester) async {
    final repo = FakeAuthRepository(delay: const Duration(milliseconds: 100));
    await pumpLogin(tester, repo);

    await fill(tester, 'customer@foodmenu.test', 'Customer@2020##');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOne);
    // A second tap during the request must not send a second one.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.calls.length, 1);
  });

  testWidgets('the stale error clears when a new attempt starts',
      (tester) async {
    final repo = FakeAuthRepository(
      loginError: const ApiException(
        failure: ApiFailure.http,
        statusCode: 401,
        message: 'That email address and password do not match an account.',
      ),
    );
    await pumpLogin(tester, repo);

    await fill(tester, 'customer@foodmenu.test', 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('do not match'), findsOne);

    repo.loginError = null;
    await fill(tester, 'customer@foodmenu.test', 'Customer@2020##');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('do not match'), findsNothing);
  });

  testWidgets('the password can be revealed', (tester) async {
    await pumpLogin(tester, FakeAuthRepository());

    expect(find.byTooltip('Show password'), findsOne);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOne);
  });
}

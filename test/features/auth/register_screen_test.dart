import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/presentation/register_screen.dart';

import 'fake_auth_repository.dart';

void main() {
  Future<ProviderContainer> pumpRegister(
    WidgetTester tester,
    FakeAuthRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Field order: first name, last name, email, phone, password.
  Future<void> fill(
    WidgetTester tester, {
    String first = 'Test',
    String last = 'Customer',
    String email = 'new@foodmenu.test',
    String phone = '',
    String password = 'Customer@2020##',
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), first);
    await tester.enterText(fields.at(1), last);
    await tester.enterText(fields.at(2), email);
    await tester.enterText(fields.at(3), phone);
    await tester.enterText(fields.at(4), password);
  }

  testWidgets('registers and signs the customer straight in', (tester) async {
    final repo = FakeAuthRepository();
    final container = await pumpRegister(tester, repo);

    await fill(tester, phone: '+1 302 555 0148');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider)?.user.email, 'new@foodmenu.test');
    final call = repo.calls.single;
    expect(call['first_name'], 'Test');
    expect(call['phone'], '+1 302 555 0148');
    // A device label is sent so the customer can tell sessions apart later.
    expect(call['device'], isNotNull);
  });

  testWidgets('an omitted phone is not sent at all', (tester) async {
    final repo = FakeAuthRepository();
    await pumpRegister(tester, repo);

    await fill(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(repo.calls.single['phone'], '');
  });

  testWidgets('requires both names, since every address needs them',
      (tester) async {
    final repo = FakeAuthRepository();
    await pumpRegister(tester, repo);

    await fill(tester, first: '', last: '');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.text('Enter your first name.'), findsOne);
    expect(find.text('Enter your last name.'), findsOne);
  });

  testWidgets('enforces the password rules before asking the server',
      (tester) async {
    final repo = FakeAuthRepository();
    await pumpRegister(tester, repo);

    await fill(tester, password: 'short');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.text('Use at least 8 characters.'), findsOne);
  });

  testWidgets('rejects a password identical to the email, as the server does',
      (tester) async {
    final repo = FakeAuthRepository();
    await pumpRegister(tester, repo);

    await fill(tester, email: 'same@foodmenu.test', password: 'same@foodmenu.test');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.textContaining('not your email address'), findsOne);
  });

  testWidgets('validates a phone when one is given', (tester) async {
    final repo = FakeAuthRepository();
    await pumpRegister(tester, repo);

    await fill(tester, phone: '12');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.textContaining('too short'), findsOne);
  });

  testWidgets('a taken email offers to sign in instead', (tester) async {
    final repo = FakeAuthRepository(
      registerError: const ApiException(
        failure: ApiFailure.http,
        statusCode: 409,
        code: 'fmp_app_email_exists',
        message:
            'An account already exists with that email address. Please sign in instead.',
      ),
    );
    await pumpRegister(tester, repo);

    await fill(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already exists'), findsOne);
    expect(find.text('Sign in instead'), findsOne);
  });

  testWidgets('another server error shows no sign-in shortcut', (tester) async {
    final repo = FakeAuthRepository(
      registerError: const ApiException(
        failure: ApiFailure.http,
        statusCode: 403,
        code: 'fmp_app_registration_disabled',
        message: 'Account registration is not available on this store.',
      ),
    );
    await pumpRegister(tester, repo);

    await fill(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not available on this store'), findsOne);
    expect(find.text('Sign in instead'), findsNothing);
  });

  testWidgets('a double tap cannot create two accounts', (tester) async {
    final repo = FakeAuthRepository(delay: const Duration(milliseconds: 100));
    await pumpRegister(tester, repo);

    await fill(tester);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.calls.length, 1);
  });
}

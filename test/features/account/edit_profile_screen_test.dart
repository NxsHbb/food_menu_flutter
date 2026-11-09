import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/account/data/profile_repository.dart';
import 'package:food_menu/src/features/account/presentation/edit_profile_screen.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_profile_repository.dart';

void main() {
  Future<({ProviderContainer container, FakeTokenStore store})> pumpEdit(
    WidgetTester tester, {
    required FakeProfileRepository profile,
    bool signedIn = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final store = FakeTokenStore();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(store),
        profileRepositoryProvider.overrideWithValue(profile),
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
          home: const EditProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, store: store);
  }

  /// First name, last name, phone — in the order the form lays them out.
  Finder field(int index) => find.byType(TextFormField).at(index);

  testWidgets('opens filled from the signed-in customer', (tester) async {
    await pumpEdit(tester, profile: FakeProfileRepository());

    // `sessionFor()` is Test Customer, with no phone.
    expect(find.widgetWithText(TextFormField, 'Test'), findsOne);
    expect(find.widgetWithText(TextFormField, 'Customer'), findsOne);
  });

  testWidgets('shows the email, and sends changing it to its own screen',
      (tester) async {
    await pumpEdit(tester, profile: FakeProfileRepository());

    expect(find.text('customer@foodmenu.test'), findsOne);
    expect(find.text('Changing this needs your password.'), findsOne);
    expect(find.text('Change'), findsOne);
    // Name, name, phone — the address is not an inline field here, because
    // changing it needs the password and replaces the session.
    expect(find.byType(TextFormField), findsExactly(3));
  });

  testWidgets('saves the changes and tells the server', (tester) async {
    final profile = FakeProfileRepository();
    await pumpEdit(tester, profile: profile);

    await tester.enterText(field(0), 'Habibur');
    await tester.enterText(field(1), 'Rahaman');
    await tester.enterText(field(2), '+8801700000000');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(profile.calls.last, {
      'call': 'update',
      'first_name': 'Habibur',
      'last_name': 'Rahaman',
      'phone': '+8801700000000',
    });
  });

  testWidgets('a saved change reaches the session and the keychain',
      (tester) async {
    final profile = FakeProfileRepository();
    final result = await pumpEdit(tester, profile: profile);

    await tester.enterText(field(0), 'Habibur');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // Without this the account header keeps the old name until a sign-in.
    expect(
      result.container.read(currentSessionProvider)?.user.firstName,
      'Habibur',
    );
    // Persisted too, or the change would not survive a restart.
    expect(result.store.calls, contains('write'));
    expect(result.store.stored?.user.firstName, 'Habibur');
  });

  testWidgets('will not submit without a first name', (tester) async {
    final profile = FakeProfileRepository();
    await pumpEdit(tester, profile: profile);

    await tester.enterText(field(0), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOne);
    expect(profile.calls, isEmpty);
  });

  testWidgets('will not submit without a last name', (tester) async {
    final profile = FakeProfileRepository();
    await pumpEdit(tester, profile: profile);

    await tester.enterText(field(1), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your last name.'), findsOne);
    expect(profile.calls, isEmpty);
  });

  testWidgets('an empty phone is fine, a short one is not', (tester) async {
    final profile = FakeProfileRepository();
    await pumpEdit(tester, profile: profile);

    await tester.enterText(field(2), '123');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('That phone number looks too short.'), findsOne);
    expect(profile.calls, isEmpty);

    // Cleared, it submits — phone is optional.
    await tester.enterText(field(2), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(profile.calls.last['call'], 'update');
  });

  testWidgets('a rejected save keeps the form and shows the reason',
      (tester) async {
    final profile = FakeProfileRepository()
      ..updateError = const ApiException(
        failure: ApiFailure.http,
        message: 'That phone number is already in use.',
        statusCode: 400,
      );
    final result = await pumpEdit(tester, profile: profile);

    await tester.enterText(field(0), 'Habibur');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('That phone number is already in use.'), findsOne);
    // The typing survives, so the customer does not start over.
    expect(find.widgetWithText(TextFormField, 'Habibur'), findsOne);
    // And the session is untouched by a save that did not happen.
    expect(
      result.container.read(currentSessionProvider)?.user.firstName,
      'Test',
    );
  });

  testWidgets('the save button is disabled while saving', (tester) async {
    final profile =
        FakeProfileRepository(delay: const Duration(milliseconds: 300));
    await pumpEdit(tester, profile: profile);

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets('renders in dark mode without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        profileRepositoryProvider
            .overrideWithValue(FakeProfileRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authControllerProvider.notifier)
        .login(username: 'customer@foodmenu.test', password: 'pw');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const EditProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

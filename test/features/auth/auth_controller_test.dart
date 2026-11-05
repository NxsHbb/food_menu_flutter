import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';

import 'fake_auth_repository.dart';

void main() {
  ProviderContainer containerWith(FakeAuthRepository repo) {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts signed out', () {
    final container = containerWith(FakeAuthRepository());
    expect(container.read(authControllerProvider), isNull);
    expect(container.read(isSignedInProvider), isFalse);
  });

  test('a successful login becomes the session', () async {
    final container = containerWith(FakeAuthRepository());

    await container
        .read(authControllerProvider.notifier)
        .login(username: 'customer@foodmenu.test', password: 'pw');

    expect(container.read(isSignedInProvider), isTrue);
    expect(container.read(authControllerProvider)?.tokens.accessToken,
        'fmpa_8_abc_access');
  });

  test('a failed login leaves the session alone and rethrows', () async {
    final repo = FakeAuthRepository(
      loginError: const ApiException(
        failure: ApiFailure.http,
        statusCode: 401,
        message: 'nope',
      ),
    );
    final container = containerWith(repo);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .login(username: 'a@b.co', password: 'pw'),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(authControllerProvider), isNull);
  });

  test('logout clears the session and tells the server which one', () async {
    final repo = FakeAuthRepository();
    final container = containerWith(repo);
    final notifier = container.read(authControllerProvider.notifier);

    await notifier.login(username: 'customer@foodmenu.test', password: 'pw');
    await notifier.logout();

    expect(container.read(authControllerProvider), isNull);
    final logout = repo.calls.last;
    expect(logout['call'], 'logout');
    expect(logout['refresh_token'], 'fmpa_8_abc_refresh');
    expect(logout['all_devices'], isFalse);
  });

  test('logout signs out locally even when the server call fails', () async {
    final repo = FakeAuthRepository(logoutError: Exception('offline'));
    final container = containerWith(repo);
    final notifier = container.read(authControllerProvider.notifier);

    await notifier.login(username: 'customer@foodmenu.test', password: 'pw');
    // Must not throw: being left signed in because the network blipped is
    // the worse of the two outcomes.
    await notifier.logout();

    expect(container.read(authControllerProvider), isNull);
  });

  test('logout while already signed out does not call the server', () async {
    final repo = FakeAuthRepository();
    final container = containerWith(repo);

    await container.read(authControllerProvider.notifier).logout();

    expect(repo.calls, isEmpty);
  });

  test('all_devices is passed through', () async {
    final repo = FakeAuthRepository();
    final container = containerWith(repo);
    final notifier = container.read(authControllerProvider.notifier);

    await notifier.login(username: 'customer@foodmenu.test', password: 'pw');
    await notifier.logout(allDevices: true);

    expect(repo.calls.last['all_devices'], isTrue);
  });
}

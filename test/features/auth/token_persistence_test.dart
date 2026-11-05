import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/domain/auth_session.dart';
import 'package:food_menu/src/features/auth/domain/auth_tokens.dart';

import 'fake_auth_repository.dart';

AuthSession expiredRefresh() {
  final base = sessionFor();
  return base.copyWith(
    tokens: AuthTokens(
      accessToken: base.tokens.accessToken,
      refreshToken: base.tokens.refreshToken,
      accessExpiresAt: DateTime.now().subtract(const Duration(days: 40)),
      refreshExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  );
}

void main() {
  ProviderContainer containerWith(FakeAuthRepository repo, FakeTokenStore store) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a stored session is restored at launch', () async {
    final store = FakeTokenStore(stored: sessionFor());
    final container = containerWith(FakeAuthRepository(), store);

    final restored = await container.read(authControllerProvider.future);

    expect(restored?.user.email, 'customer@foodmenu.test');
    expect(container.read(isSignedInProvider), isTrue);
  });

  test('an empty store launches signed out', () async {
    final container = containerWith(FakeAuthRepository(), FakeTokenStore());

    expect(await container.read(authControllerProvider.future), isNull);
    expect(container.read(isSignedInProvider), isFalse);
  });

  test('signing in writes the session to the store', () async {
    final store = FakeTokenStore();
    final container = containerWith(FakeAuthRepository(), store);
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(username: 'customer@foodmenu.test', password: 'pw');

    expect(store.stored?.user.email, 'customer@foodmenu.test');
    expect(store.calls, contains('write'));
  });

  test('logging out wipes the store, not just memory', () async {
    final store = FakeTokenStore(stored: sessionFor());
    final container = containerWith(FakeAuthRepository(), store);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();

    expect(store.stored, isNull);
    expect(store.calls, contains('clear'));
    expect(container.read(currentSessionProvider), isNull);
  });

  test('a refresh token past its life is not worth sending', () async {
    final repo = FakeAuthRepository();
    final store = FakeTokenStore(stored: expiredRefresh());
    final container = containerWith(repo, store);
    await container.read(authControllerProvider.future);

    final ok = await container.read(authControllerProvider.notifier).refresh();

    expect(ok, isFalse);
    // The point: no request was made, and the dead session was cleared.
    expect(repo.calls.where((c) => c['call'] == 'refresh'), isEmpty);
    expect(container.read(currentSessionProvider), isNull);
    expect(store.stored, isNull);
  });

  test('a successful refresh persists the rotated pair', () async {
    final repo = FakeAuthRepository();
    final store = FakeTokenStore(stored: sessionFor());
    final container = containerWith(repo, store);
    await container.read(authControllerProvider.future);

    final ok = await container.read(authControllerProvider.notifier).refresh();

    expect(ok, isTrue);
    expect(repo.calls.last['call'], 'refresh');
    expect(store.calls, contains('write'));
    // The rotated pair must replace the old one everywhere, or the next
    // request would replay a spent token and burn the session.
    expect(store.stored?.tokens.refreshToken, endsWith('_rotated'));
    expect(
      container.read(currentSessionProvider)?.tokens.accessToken,
      endsWith('_rotated'),
    );
    // The user survives a rotation; only the tokens change.
    expect(container.read(currentSessionProvider)?.user.email,
        'customer@foodmenu.test');
  });

  test('concurrent refreshes make exactly one request', () async {
    // The server revokes the session when a spent refresh token is replayed,
    // so a second concurrent refresh would sign the customer out.
    final repo = FakeAuthRepository(delay: const Duration(milliseconds: 40));
    final store = FakeTokenStore(stored: sessionFor());
    final container = containerWith(repo, store);
    await container.read(authControllerProvider.future);

    final notifier = container.read(authControllerProvider.notifier);
    final results = await Future.wait([
      notifier.refresh(),
      notifier.refresh(),
      notifier.refresh(),
      notifier.refresh(),
    ]);

    expect(results, everyElement(isTrue));
    expect(repo.calls.where((c) => c['call'] == 'refresh').length, 1);
  });

  test('a rejected refresh signs out and clears storage', () async {
    final repo = FakeAuthRepository(
      refreshError: const ApiException(
        failure: ApiFailure.http,
        statusCode: 401,
        code: 'fmp_app_refresh_reused',
        message: 'This session has been signed out. Please sign in again.',
      ),
    );
    final store = FakeTokenStore(stored: sessionFor());
    final container = containerWith(repo, store);
    await container.read(authControllerProvider.future);

    final ok = await container.read(authControllerProvider.notifier).refresh();

    expect(ok, isFalse);
    expect(container.read(currentSessionProvider), isNull);
    expect(store.stored, isNull);
  });

  test('a network blip during refresh keeps the session', () async {
    // Losing a thirty-day session because the tunnel dropped would be far
    // worse than retrying on the next request.
    final repo = FakeAuthRepository(
      refreshError: const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server.',
      ),
    );
    final store = FakeTokenStore(stored: sessionFor());
    final container = containerWith(repo, store);
    await container.read(authControllerProvider.future);

    final ok = await container.read(authControllerProvider.notifier).refresh();

    expect(ok, isFalse);
    expect(container.read(currentSessionProvider), isNotNull);
    expect(store.stored, isNotNull);
  });

  test('a second refresh after one completes does issue a new request', () async {
    final repo = FakeAuthRepository();
    final store = FakeTokenStore(stored: sessionFor());
    final container = containerWith(repo, store);
    await container.read(authControllerProvider.future);

    final notifier = container.read(authControllerProvider.notifier);
    await notifier.refresh();
    await notifier.refresh();

    // The single-flight guard must not latch permanently.
    expect(repo.calls.where((c) => c['call'] == 'refresh').length, 2);
  });
}

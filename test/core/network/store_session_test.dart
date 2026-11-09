import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/store_session.dart';
import 'package:food_menu/src/core/network/store_session_store.dart';

import 'fake_store_session_store.dart';

void main() {
  late FakeStoreSessionStore store;

  /// Builds the container **and** the store it reads, so a test can only ever
  /// assert on the instance actually in use.
  ProviderContainer containerWith({String? stored}) {
    store = FakeStoreSessionStore(stored: stored);
    final container = ProviderContainer(
      overrides: [storeSessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('restoring', () {
    test('a stored cart token comes back on the next launch', () async {
      final token = cartToken();
      final container = containerWith(stored: token);

      final session = await container.read(storeSessionProvider.future);

      expect(session.cartToken, token);
      // The nonce is never stored: it comes back on every response, and a
      // stale one is worse than none.
      expect(session.nonce, isNull);
    });

    test('no stored token is an empty session, not a failure', () async {
      final container = containerWith();

      final session = await container.read(storeSessionProvider.future);

      expect(session.cartToken, isNull);
      expect(session.canWrite, isFalse);
    });
  });

  group('absorbing', () {
    test('a new cart token is persisted', () async {
      final container = containerWith();
      await container.read(storeSessionProvider.future);

      final token = cartToken();
      container
          .read(storeSessionProvider.notifier)
          .absorb(nonce: 'abc', cartToken: token);

      await Future<void>.delayed(Duration.zero);
      expect(store.writes, [token]);
    });

    test('the same token again is not written again', () async {
      final token = cartToken();
      final container = containerWith(stored: token);
      await container.read(storeSessionProvider.future);

      container
          .read(storeSessionProvider.notifier)
          .absorb(nonce: 'one', cartToken: token);
      container
          .read(storeSessionProvider.notifier)
          .absorb(nonce: 'two', cartToken: token);

      await Future<void>.delayed(Duration.zero);
      expect(store.writes, isEmpty);
    });

    test('a nonce alone never erases the token', () async {
      final token = cartToken();
      final container = containerWith(stored: token);
      await container.read(storeSessionProvider.future);

      container.read(storeSessionProvider.notifier).absorb(nonce: 'fresh');

      expect(
        container.read(storeSessionProvider).value!.cartToken,
        token,
      );
    });

    test('a reissued token replaces the stored one', () async {
      final first = cartToken(id: 't_one');
      final container = containerWith(stored: first);
      await container.read(storeSessionProvider.future);

      final second = cartToken(id: 't_two');
      container
          .read(storeSessionProvider.notifier)
          .absorb(cartToken: second);

      await Future<void>.delayed(Duration.zero);
      expect(store.writes, [second]);
      expect(store.stored, second);
    });
  });

  test('clearing wipes the stored copy as well as the live one', () async {
    final container = containerWith(stored: cartToken());
    await container.read(storeSessionProvider.future);

    await container.read(storeSessionProvider.notifier).clear();

    // Otherwise the next launch restores a cart that has already been paid
    // for.
    expect(container.read(storeSessionProvider).value!.cartToken, isNull);
    expect(store.stored, isNull);
  });

  group('expiry', () {
    test('a token past its exp is not sent', () {
      expect(
        SecureStoreSessionStore.isExpired(cartToken(inDays: -1)),
        isTrue,
      );
    });

    test('a live token is kept', () {
      expect(SecureStoreSessionStore.isExpired(cartToken()), isFalse);
    });

    test('a token the app cannot read is left for the server to judge', () {
      // Not our call to make: a shape this build has never seen may still be
      // perfectly good.
      expect(SecureStoreSessionStore.isExpired('not-a-jwt'), isFalse);
      expect(SecureStoreSessionStore.isExpired('a.b.c'), isFalse);
      expect(SecureStoreSessionStore.isExpired(''), isFalse);
    });

    test('a token with no exp claim is kept', () {
      const noExpiry =
          'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidF9hYmMifQ.signature';

      expect(SecureStoreSessionStore.isExpired(noExpiry), isFalse);
    });
  });
}

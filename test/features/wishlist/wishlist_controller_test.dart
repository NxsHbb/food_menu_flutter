import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_controller.dart';
import 'package:food_menu/src/features/wishlist/data/wishlist_repository.dart';

import '../auth/fake_auth_repository.dart';
import '../menu/fake_menu_repository.dart';
import 'fake_wishlist_repository.dart';

void main() {
  /// A container whose auth state can be driven, since the wishlist only
  /// loads for a signed-in customer.
  Future<ProviderContainer> containerFor(
    FakeWishlistRepository wishlist, {
    bool signedIn = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        wishlistRepositoryProvider.overrideWithValue(wishlist),
      ],
    );
    addTearDown(container.dispose);

    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
    } else {
      await container.read(authControllerProvider.future);
    }

    return container;
  }

  final latte = buildProduct(id: 26, name: 'Iced Latte', price: '450');
  final lemonade = buildProduct(id: 25, name: 'Fresh Lemonade', price: '350');

  test('signed out, the wishlist is empty and the server is never asked',
      () async {
    final repo = FakeWishlistRepository(saved: [latte]);
    final container = await containerFor(repo, signedIn: false);

    expect(await container.read(wishlistControllerProvider.future), isEmpty);
    expect(repo.calls, isEmpty);
  });

  test('signing in loads the wishlist', () async {
    final repo = FakeWishlistRepository(saved: [lemonade, latte]);
    final container = await containerFor(repo);

    final saved = await container.read(wishlistControllerProvider.future);

    expect(saved.map((p) => p.id), [25, 26]);
    expect(container.read(wishlistIdsProvider), {25, 26});
    expect(container.read(wishlistCountProvider), 2);
  });

  test('signing out drops the wishlist without asking the server', () async {
    final repo = FakeWishlistRepository(saved: [latte]);
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();

    expect(await container.read(wishlistControllerProvider.future), isEmpty);
    expect(container.read(wishlistIdsProvider), isEmpty);
  });

  test('favouriting shows the dish before the server replies', () async {
    final repo = FakeWishlistRepository(delay: const Duration(seconds: 1))
      ..catalogue[26] = latte;
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    final pending =
        container.read(wishlistControllerProvider.notifier).toggle(latte);

    // One turn of the event loop, not the second the add takes: `toggle`
    // awaits the load before touching state, so the optimistic update lands a
    // microtask after the call rather than synchronously.
    await Future<void>.delayed(Duration.zero);

    // The add is still in flight, but the heart is already filled.
    expect(container.read(wishlistIdsProvider), {26});
    expect(repo.saved, isEmpty);

    await pending;
    expect(repo.saved.map((p) => p.id), [26]);
  });

  test('a saved dish is prepended, so the newest favourite is first',
      () async {
    final repo = FakeWishlistRepository(saved: [lemonade])
      ..catalogue[26] = latte;
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    await container.read(wishlistControllerProvider.notifier).toggle(latte);

    expect(container.read(wishlistControllerProvider).value!.map((p) => p.id),
        [26, 25]);
  });

  test('unfavouriting removes the dish', () async {
    final repo = FakeWishlistRepository(saved: [latte, lemonade]);
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    await container.read(wishlistControllerProvider.notifier).toggle(latte);

    expect(container.read(wishlistIdsProvider), {25});
    expect(repo.calls.last, (call: 'remove', productId: 26));
  });

  test('a failed add is reverted and the error rethrown', () async {
    final repo = FakeWishlistRepository()
      ..writeError = const ApiException(
        failure: ApiFailure.http,
        message: 'Nope',
        statusCode: 500,
      );
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    await expectLater(
      container.read(wishlistControllerProvider.notifier).toggle(latte),
      throwsA(isA<ApiException>()),
    );

    // Reverted, not left showing a favourite the server does not have.
    expect(container.read(wishlistIdsProvider), isEmpty);
  });

  test('a failed remove puts the dish back', () async {
    final repo = FakeWishlistRepository(saved: [latte])
      ..writeError = const ApiException(
        failure: ApiFailure.network,
        message: 'Offline',
      );
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    await expectLater(
      container.read(wishlistControllerProvider.notifier).toggle(latte),
      throwsA(isA<ApiException>()),
    );

    expect(container.read(wishlistIdsProvider), {26});
  });

  test('the wishlist cap surfaces as an error, with the list unchanged',
      () async {
    final repo = FakeWishlistRepository(saved: [lemonade])
      ..writeError = const ApiException(
        failure: ApiFailure.http,
        message: 'Your wishlist is full. You can save up to 100 dishes.',
        statusCode: 409,
        code: 'fmp_app_wishlist_full',
      );
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    await expectLater(
      container.read(wishlistControllerProvider.notifier).toggle(latte),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
      ),
    );

    expect(container.read(wishlistIdsProvider), {25});
  });

  test('a 404 reloads the wishlist, because the held list is stale', () async {
    // The dish has left the menu. The server drops it from the wishlist, so
    // reverting alone would leave the app showing a dish that is gone.
    final repo = FakeWishlistRepository(saved: [latte, lemonade])
      ..writeError = const ApiException(
        failure: ApiFailure.http,
        message: 'That dish is not on the menu.',
        statusCode: 404,
      );
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    // The server has since dropped it from what it will return.
    repo.saved.removeWhere((p) => p.id == 26);

    await expectLater(
      container.read(wishlistControllerProvider.notifier).toggle(latte),
      throwsA(isA<ApiException>()),
    );
    await container.read(wishlistControllerProvider.future);

    expect(container.read(wishlistIdsProvider), {25});
    expect(repo.calls.where((c) => c.call == 'all').length, 2);
  });

  test('a tap during the first load still applies', () async {
    final repo = FakeWishlistRepository(delay: const Duration(seconds: 1))
      ..catalogue[26] = latte;
    final container = await containerFor(repo);

    // Deliberately not awaiting the load first — this is the window when a
    // customer is first looking at the menu.
    await container.read(wishlistControllerProvider.notifier).toggle(latte);

    expect(container.read(wishlistIdsProvider), {26});
    expect(repo.saved.map((p) => p.id), [26]);
  });

  test('reload re-reads the list', () async {
    final repo = FakeWishlistRepository(saved: [latte]);
    final container = await containerFor(repo);
    await container.read(wishlistControllerProvider.future);

    repo.saved.insert(0, lemonade);
    await container.read(wishlistControllerProvider.notifier).reload();

    expect(container.read(wishlistIdsProvider), {25, 26});
  });

  test('a failed load surfaces as an error state', () async {
    final repo = FakeWishlistRepository()
      ..loadError = const ApiException(
        failure: ApiFailure.network,
        message: 'Offline',
      );
    final container = await containerFor(repo);

    await expectLater(
      container.read(wishlistControllerProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(wishlistIdsProvider), isEmpty);
  });
}

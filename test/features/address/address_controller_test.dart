import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/features/address/data/address_controller.dart';
import 'package:food_menu/src/features/address/data/address_repository.dart';
import 'package:food_menu/src/features/address/domain/saved_address.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_address_repository.dart';

void main() {
  Future<ProviderContainer> containerFor(
    FakeAddressRepository repo, {
    bool signedIn = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        addressRepositoryProvider.overrideWithValue(repo),
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

  final home = buildAddress(id: 'home', label: 'Home', isDefault: true);
  final work = buildAddress(
    id: 'work',
    label: 'Work',
    address1: '1200 Main St',
    locality: 'Dover, Delaware 19901',
  );

  test('signed out, the book is empty and the server is never asked',
      () async {
    final repo = FakeAddressRepository(book: [home]);
    final container = await containerFor(repo, signedIn: false);

    expect(await container.read(addressControllerProvider.future), isEmpty);
    expect(repo.calls, isEmpty);
  });

  test('signing in loads the book', () async {
    final repo = FakeAddressRepository(book: [home, work]);
    final container = await containerFor(repo);

    final book = await container.read(addressControllerProvider.future);

    expect(book.map((a) => a.id), ['home', 'work']);
    expect(container.read(addressCountProvider), 2);
  });

  test('adding keeps every address already in the book', () async {
    // The whole point of the controller: the endpoint replaces the book, so
    // an add that forgot the existing entries would delete them.
    final repo = FakeAddressRepository(book: [home, work]);
    final container = await containerFor(repo);
    await container.read(addressControllerProvider.future);

    await container.read(addressControllerProvider.notifier).save(
          const SavedAddress(label: 'Gym', address1: '5 Park Row'),
        );

    expect(repo.lastSubmitted!.map((a) => a.label), ['Home', 'Work', 'Gym']);
    expect(container.read(addressCountProvider), 3);
  });

  test('editing replaces in place rather than appending', () async {
    final repo = FakeAddressRepository(book: [home, work]);
    final container = await containerFor(repo);
    await container.read(addressControllerProvider.future);

    await container
        .read(addressControllerProvider.notifier)
        .save(work.copyWith(address1: '9 New Road'));

    expect(repo.lastSubmitted, hasLength(2));
    expect(repo.lastSubmitted!.last.address1, '9 New Road');
  });

  test('removing sends everything except that address', () async {
    final repo = FakeAddressRepository(book: [home, work]);
    final container = await containerFor(repo);
    await container.read(addressControllerProvider.future);

    await container.read(addressControllerProvider.notifier).remove('home');

    expect(repo.lastSubmitted!.map((a) => a.id), ['work']);
  });

  test('setting a default clears it everywhere else', () async {
    final repo = FakeAddressRepository(book: [home, work]);
    final container = await containerFor(repo);
    await container.read(addressControllerProvider.future);

    await container.read(addressControllerProvider.notifier).setDefault('work');

    // Two defaults would let the server pick, which is not the same as the
    // customer choosing.
    final defaults =
        repo.lastSubmitted!.where((a) => a.isDefault).map((a) => a.id);
    expect(defaults, ['work']);
  });

  test('saving a new default demotes the old one', () async {
    final repo = FakeAddressRepository(book: [home]);
    final container = await containerFor(repo);
    await container.read(addressControllerProvider.future);

    await container.read(addressControllerProvider.notifier).save(
          const SavedAddress(
            label: 'Gym',
            address1: '5 Park Row',
            isDefault: true,
          ),
        );

    final defaults =
        repo.lastSubmitted!.where((a) => a.isDefault).map((a) => a.label);
    expect(defaults, ['Gym']);
  });

  test('the state the server returns replaces what was sent', () async {
    // The server resolves a state name to a code, formats a postcode and
    // builds `locality`. Keeping the local guess would show a stale card.
    final repo = FakeAddressRepository();
    final container = await containerFor(repo);
    await container.read(addressControllerProvider.future);

    await container.read(addressControllerProvider.notifier).save(
          const SavedAddress(
            label: 'Home',
            address1: '6391 Elgin St.',
            city: 'Celina',
            state: 'DE',
            postcode: '10299',
          ),
        );

    final saved = container.read(addressControllerProvider).value!.single;
    expect(saved.id, isNotNull, reason: 'the server assigns the id');
    expect(saved.locality, 'Celina DE 10299');
  });

  group('a rejected save', () {
    ApiException invalid({required String field, required int index}) {
      return ApiException(
        failure: ApiFailure.http,
        message: 'ZIP Code is required for the selected country.',
        statusCode: 400,
        code: 'fmp_app_invalid_address',
        field: field,
        index: index,
      );
    }

    test('is blamed on this address when the index matches', () async {
      final repo = FakeAddressRepository(book: [home])
        ..saveError = invalid(field: 'postcode', index: 1);
      final container = await containerFor(repo);
      await container.read(addressControllerProvider.future);

      await expectLater(
        container.read(addressControllerProvider.notifier).save(
              const SavedAddress(label: 'Gym', address1: '5 Park Row'),
            ),
        throwsA(
          isA<AddressSaveException>()
              .having((e) => e.isThisAddress, 'isThisAddress', isTrue)
              .having((e) => e.field, 'field', 'postcode'),
        ),
      );
    });

    test('is not blamed on this address when the index is another entry',
        () async {
      // Editing one address can fail because a *different* saved one is
      // invalid — the book is submitted whole. Blaming this form's input
      // would point the customer at the wrong field.
      final repo = FakeAddressRepository(book: [home, work])
        ..saveError = invalid(field: 'postcode', index: 0);
      final container = await containerFor(repo);
      await container.read(addressControllerProvider.future);

      await expectLater(
        container
            .read(addressControllerProvider.notifier)
            .save(work.copyWith(address1: '9 New Road')),
        throwsA(
          isA<AddressSaveException>()
              .having((e) => e.isThisAddress, 'isThisAddress', isFalse),
        ),
      );
    });

    test('leaves the book as it was', () async {
      final repo = FakeAddressRepository(book: [home])
        ..saveError = invalid(field: 'postcode', index: 1);
      final container = await containerFor(repo);
      await container.read(addressControllerProvider.future);

      await container
          .read(addressControllerProvider.notifier)
          .save(const SavedAddress(label: 'Gym'))
          .catchError((Object _) {});

      expect(container.read(addressControllerProvider).value!.map((a) => a.id),
          ['home']);
    });

    test('a non-address error is not pinned to any field', () async {
      final repo = FakeAddressRepository()
        ..saveError = const ApiException(
          failure: ApiFailure.network,
          message: 'Offline',
        );
      final container = await containerFor(repo);
      await container.read(addressControllerProvider.future);

      await expectLater(
        container
            .read(addressControllerProvider.notifier)
            .save(const SavedAddress(label: 'Gym')),
        throwsA(
          isA<AddressSaveException>()
              .having((e) => e.field, 'field', isNull)
              .having((e) => e.isThisAddress, 'isThisAddress', isFalse),
        ),
      );
    });
  });

  test('a failed load surfaces as an error state', () async {
    final repo = FakeAddressRepository()
      ..loadError = const ApiException(
        failure: ApiFailure.network,
        message: 'Offline',
      );
    final container = await containerFor(repo);

    await expectLater(
      container.read(addressControllerProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(addressCountProvider), 0);
  });
}

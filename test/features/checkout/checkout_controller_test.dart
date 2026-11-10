import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/features/address/data/address_controller.dart';
import 'package:food_menu/src/features/address/data/address_repository.dart';
import 'package:food_menu/src/features/address/domain/saved_address.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/checkout/data/checkout_controller.dart';

import '../address/fake_address_repository.dart';
import '../auth/fake_auth_repository.dart';

void main() {
  final home = buildAddress(id: 'home', label: 'Home', isDefault: true);
  final work = buildAddress(
    id: 'work',
    label: 'Work',
    address1: '2118 Thornridge Cir.',
    firstName: 'Work',
    lastName: 'Name',
    phone: '01911 222333',
  );

  Future<ProviderContainer> containerWith({
    List<SavedAddress> book = const [],
    bool signedIn = true,
    String firstName = 'Test',
    String lastName = 'Customer',
    String phone = '',
  }) async {
    final auth = FakeAuthRepository(
      session: sessionFor(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        addressRepositoryProvider
            .overrideWithValue(FakeAddressRepository(book: book)),
        authRepositoryProvider.overrideWithValue(auth),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
    }
    // The book is read lazily, so nothing resolves until it has arrived.
    await container.read(addressControllerProvider.future);

    return container;
  }

  group('the address for the order', () {
    test('is the chosen one', () async {
      final container = await containerWith(book: [home, work]);

      container
          .read(checkoutControllerProvider.notifier)
          .chooseAddress('work');

      expect(container.read(checkoutAddressProvider)?.id, 'work');
    });

    test('is the default one until something is chosen', () async {
      final container = await containerWith(book: [work, home]);

      expect(container.read(checkoutAddressProvider)?.id, 'home');
    });

    test('falls back when the chosen one is gone', () async {
      // Deleted, or signed out and in as somebody else. Resolved on every
      // read so the screen is never pointed at an address the server has
      // never heard of.
      final container = await containerWith(book: [home, work]);

      container
          .read(checkoutControllerProvider.notifier)
          .chooseAddress('deleted');

      expect(container.read(checkoutAddressProvider)?.id, 'home');
    });

    test('is the first when the book marks no default', () async {
      final container = await containerWith(
        book: [work, home.copyWith(isDefault: false)],
      );

      expect(container.read(checkoutAddressProvider)?.id, 'work');
    });

    test('is null with nothing saved', () async {
      final container = await containerWith();

      expect(container.read(checkoutAddressProvider), isNull);
    });
  });

  group('the contact details', () {
    test('come from the account first', () async {
      final container = await containerWith(
        book: [work],
        firstName: 'Jamal',
        lastName: 'Uddin',
        phone: '01711 000111',
      );

      final contact = container.read(checkoutContactProvider);
      expect(contact.name, 'Jamal Uddin');
      expect(contact.phone, '01711 000111');
      expect(contact.isComplete, isTrue);
    });

    test('fall back to the address for what the account lacks', () async {
      final container = await containerWith(book: [work]);
      container
          .read(checkoutControllerProvider.notifier)
          .chooseAddress('work');

      // The name is still the account's; only the phone is missing there.
      expect(container.read(checkoutContactProvider).phone, '01911 222333');
    });

    test('never fall back to the email address', () async {
      // `AuthUser.greetingName` does, which is right for a greeting and wrong
      // in a field the kitchen prints on a ticket.
      final container = await containerWith(firstName: '', lastName: '');

      expect(container.read(checkoutContactProvider).name, isNot(contains('@')));
    });

    test('are whatever was typed, including cleared', () async {
      final container = await containerWith(
        book: [home],
        firstName: 'Jamal',
        lastName: 'Uddin',
      );
      final controller = container.read(checkoutControllerProvider.notifier);

      controller.setName('Someone Else');
      expect(container.read(checkoutContactProvider).name, 'Someone Else');

      controller.setName('');
      expect(container.read(checkoutContactProvider).name, '');
      expect(container.read(checkoutContactProvider).isComplete, isFalse);
    });
  });
}

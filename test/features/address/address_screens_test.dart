import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/address/data/address_repository.dart';
import 'package:food_menu/src/features/address/presentation/address_book_screen.dart';
import 'package:food_menu/src/features/address/presentation/address_form_screen.dart';
import 'package:food_menu/src/features/address/presentation/widgets/address_card.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/auth/presentation/login_screen.dart';
import 'package:go_router/go_router.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_address_repository.dart';

void main() {
  /// Both screens behind a router, since the list pushes the form.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required FakeAddressRepository repo,
    bool signedIn = true,
    String location = '/account/addresses',
    ThemeData? theme,
  }) async {
    // The reported device's **width**, which is where layout bugs live, but a
    // tall viewport so the whole form builds. The address form is a ListView
    // and at a real 800dp height its lower fields are never constructed, so
    // assertions about them would fail on virtualisation rather than on
    // anything real.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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
    }

    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/account',
          name: 'account',
          builder: (context, state) => const Scaffold(body: Text('Account')),
          routes: [
            GoRoute(
              path: AddressBookScreen.routePath,
              name: AddressBookScreen.routeName,
              builder: (context, state) => const AddressBookScreen(),
            ),
            GoRoute(
              path: AddressFormScreen.newRoutePath,
              name: AddressFormScreen.newRouteName,
              builder: (context, state) => const AddressFormScreen(),
            ),
            GoRoute(
              path: AddressFormScreen.routePath,
              name: AddressFormScreen.routeName,
              builder: (context, state) =>
                  AddressFormScreen(addressId: state.pathParameters['id']),
            ),
          ],
        ),
        GoRoute(
          path: LoginScreen.routePath,
          name: LoginScreen.routeName,
          builder: (context, state) => const LoginScreen(),
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
    return container;
  }

  final home = buildAddress(id: 'home', label: 'Home', isDefault: true);
  final work = buildAddress(
    id: 'work',
    label: 'Work',
    address1: '1200 Main St',
    locality: 'Dover, Delaware 19901',
  );

  /// The US form requires a state, and it is a picker — a test that only
  /// fills the text inputs never gets past validation.
  Future<void> pickState(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delaware').last);
    await tester.pumpAndSettle();
  }

  group('address book', () {
    testWidgets('lists the saved addresses', (tester) async {
      await pump(tester, repo: FakeAddressRepository(book: [home, work]));

      expect(find.byType(AddressCard), findsExactly(2));
      expect(find.text('6391 Elgin St.'), findsOne);
      expect(find.text('Celina, Delaware 10299'), findsOne);
      expect(find.text('Home'), findsOne);
    });

    testWidgets('marks the default one', (tester) async {
      await pump(tester, repo: FakeAddressRepository(book: [home, work]));

      expect(find.text('Default'), findsOne);
    });

    testWidgets('a book with no default shows no badge', (tester) async {
      // The seeded book on the dev site is exactly this: addresses saved
      // before anything set a default.
      await pump(
        tester,
        repo: FakeAddressRepository(
          book: [home.copyWith(isDefault: false), work],
        ),
      );

      expect(find.text('Default'), findsNothing);
      expect(find.byType(AddressCard), findsExactly(2));
    });

    testWidgets('an empty book explains what to do', (tester) async {
      await pump(tester, repo: FakeAddressRepository());

      expect(find.text('No saved addresses'), findsOne);
      expect(find.byType(AddressCard), findsNothing);
    });

    testWidgets('signed out, it invites the customer to sign in',
        (tester) async {
      final repo = FakeAddressRepository(book: [home]);
      await pump(tester, repo: repo, signedIn: false);

      expect(find.text('Sign in'), findsOne);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final repo = FakeAddressRepository()
        ..loadError = const ApiException(
          failure: ApiFailure.network,
          message: 'Could not reach the server.',
        );
      await pump(tester, repo: repo);

      expect(find.text('Could not reach the server.'), findsOne);

      repo
        ..loadError = null
        ..book = [home];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(AddressCard), findsOne);
    });

    testWidgets('deleting removes the card', (tester) async {
      final repo = FakeAddressRepository(book: [home, work]);
      await pump(tester, repo: repo);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete address'));
      await tester.pumpAndSettle();

      expect(find.byType(AddressCard), findsOne);
      expect(find.text('1200 Main St'), findsNothing);
    });

    testWidgets('setting a default moves the badge', (tester) async {
      final repo = FakeAddressRepository(book: [home, work]);
      await pump(tester, repo: repo);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set as default'));
      await tester.pumpAndSettle();

      final defaults =
          repo.lastSubmitted!.where((a) => a.isDefault).map((a) => a.id);
      expect(defaults, ['work']);
    });

    testWidgets('the default address offers no "set as default"',
        (tester) async {
      await pump(tester, repo: FakeAddressRepository(book: [home]));

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Set as default'), findsNothing);
      expect(find.text('Delete address'), findsOne);
    });

    testWidgets('renders in dark mode without overflow', (tester) async {
      await pump(
        tester,
        repo: FakeAddressRepository(book: [home, work]),
        theme: AppTheme.dark(),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AddressCard), findsExactly(2));
    });
  });

  group('address form', () {
    testWidgets('draws the fields the server describes, in its order',
        (tester) async {
      await pump(
        tester,
        repo: FakeAddressRepository(),
        location: '/account/addresses/new',
      );

      // The server's own labels, not ours. A required field is marked.
      expect(find.text('Street address *'), findsOne);
      expect(find.text('ZIP Code *'), findsOne);
      expect(find.text('State *'), findsOne);
      // `company` is not in the US field list, so it must not be drawn.
      expect(find.textContaining('Company'), findsNothing);
    });

    testWidgets('a state with a list is a picker', (tester) async {
      await pump(
        tester,
        repo: FakeAddressRepository(),
        location: '/account/addresses/new',
      );

      expect(
        find.byType(DropdownButtonFormField<String>),
        // Country and state.
        findsExactly(2),
      );
    });

    testWidgets('a state with no list is a text field', (tester) async {
      await pump(
        tester,
        repo: FakeAddressRepository(fieldsFor: gbFields()),
        location: '/account/addresses/new',
      );

      // Country only — the UK state is free text, and optional.
      expect(find.byType(DropdownButtonFormField<String>), findsOne);
      expect(find.text('County'), findsOne);
      expect(find.text('Postcode *'), findsOne);
    });

    testWidgets('opens filled when editing', (tester) async {
      await pump(
        tester,
        repo: FakeAddressRepository(book: [home]),
        location: '/account/addresses/home',
      );

      expect(find.text('Edit address'), findsOne);
      expect(find.widgetWithText(TextFormField, '6391 Elgin St.'), findsOne);
      expect(find.widgetWithText(TextFormField, 'Home'), findsOne);
    });

    testWidgets('refuses to submit without a required field', (tester) async {
      final repo = FakeAddressRepository();
      await pump(
        tester,
        repo: repo,
        location: '/account/addresses/new',
      );

      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();

      expect(find.text('Street address is required.'), findsOne);
      expect(repo.calls, isNot(contains('replace')));
    });

    testWidgets('an optional field may be left blank', (tester) async {
      // The UK county is optional, so a form that demanded it would be
      // wrong — and that is precisely what hard-coding would have produced.
      final repo = FakeAddressRepository(fieldsFor: gbFields());
      await pump(
        tester,
        repo: repo,
        location: '/account/addresses/new',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '').first,
        'Jane',
      );
      await tester.pumpAndSettle();

      expect(find.text('County is required.'), findsNothing);
    });

    testWidgets('a rejection for this address lands on its field',
        (tester) async {
      final repo = FakeAddressRepository()
        ..saveError = const ApiException(
          failure: ApiFailure.http,
          message: 'ZIP Code is required for the selected country.',
          statusCode: 400,
          code: 'fmp_app_invalid_address',
          field: 'postcode',
          index: 0,
        );
      await pump(
        tester,
        repo: repo,
        location: '/account/addresses/new',
      );

      for (final (index, value) in [
        'Test',
        'Customer',
        '6391 Elgin St.',
        'Celina',
        '10299',
      ].indexed) {
        await tester.enterText(find.byType(TextFormField).at(index + 1), value);
      }
      await pickState(tester);
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();

      expect(
        find.text('ZIP Code is required for the selected country.'),
        findsAtLeast(1),
      );
    });

    testWidgets('a rejection for another address says so instead',
        (tester) async {
      final repo = FakeAddressRepository(book: [home])
        ..saveError = const ApiException(
          failure: ApiFailure.http,
          message: 'ZIP Code is required for the selected country.',
          statusCode: 400,
          code: 'fmp_app_invalid_address',
          field: 'postcode',
          // Index 0 is the existing address, not the one being added.
          index: 0,
        );
      await pump(
        tester,
        repo: repo,
        location: '/account/addresses/new',
      );

      for (final (index, value) in [
        'Test',
        'Customer',
        '6391 Elgin St.',
        'Celina',
        '10299',
      ].indexed) {
        await tester.enterText(find.byType(TextFormField).at(index + 1), value);
      }
      await pickState(tester);
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Another saved address needs fixing'),
        findsOne,
      );
    });

    testWidgets('changing country refetches the form for it', (tester) async {
      final repo = FakeAddressRepository();
      await pump(
        tester,
        repo: repo,
        location: '/account/addresses/new',
      );

      expect(find.text('ZIP Code *'), findsOne);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('United Kingdom').last);
      await tester.pumpAndSettle();

      expect(repo.requestedCountries, contains('GB'));
      // The UK form, not the US one it was showing a moment ago.
      expect(find.text('Postcode *'), findsOne);
      expect(find.text('ZIP Code *'), findsNothing);
    });

    testWidgets('renders in dark mode without overflow', (tester) async {
      await pump(
        tester,
        repo: FakeAddressRepository(),
        location: '/account/addresses/new',
        theme: AppTheme.dark(),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

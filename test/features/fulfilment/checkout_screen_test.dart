import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/cart/data/cart_repository.dart';
import 'package:food_menu/src/features/fulfilment/data/fulfilment_repository.dart';
import 'package:food_menu/src/features/fulfilment/presentation/checkout_screen.dart';
import 'package:go_router/go_router.dart';

import '../cart/fake_cart_repository.dart';
import 'fake_fulfilment_repository.dart';

void main() {
  late FakeFulfilmentRepository repo;
  late FakeCartRepository cartRepo;

  setUp(() {
    repo = FakeFulfilmentRepository();
    cartRepo = FakeCartRepository(cart: cartFromFixture('cart_with_item'));
  });

  Future<void> pump(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    final router = GoRouter(
      initialLocation: CheckoutScreen.routePath,
      routes: [
        GoRoute(
          path: CheckoutScreen.routePath,
          name: CheckoutScreen.routeName,
          builder: (_, _) => const CheckoutScreen(),
        ),
        GoRoute(path: '/cart', name: 'cart', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fulfilmentRepositoryProvider.overrideWithValue(repo),
          cartRepositoryProvider.overrideWithValue(cartRepo),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('both types are offered, with the store\'s labels', (tester) async {
    await pump(tester);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('the slot list opens on delivery, as the design does',
      (tester) async {
    await pump(tester);

    // Delivery's own windows, not pickup's point times.
    expect(find.text('Delivery time'), findsOneWidget);
    expect(find.text('ASAP (20–35 min)'), findsOneWidget);
    expect(find.text('11:00 pm – 11:15 pm'), findsOneWidget);
  });

  testWidgets('switching to pickup asks the server again and redraws',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup time'), findsOneWidget);
    expect(find.text('ASAP (15 min)'), findsOneWidget);
    expect(find.text('11:00 pm'), findsOneWidget);
    expect(repo.calls, contains('slots pickup - 26:2'));
  });

  testWidgets('a full slot is drawn struck through and explains itself',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    final full = tester.widget<Text>(find.text('11:15 pm'));
    expect(full.style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.text('11:15 pm'));
    await tester.pump();

    // The store's own sentence, not one composed here.
    expect(find.text('This time slot is full.'), findsOneWidget);
  });

  testWidgets('tapping an open slot selects it and keeps the list', (tester) async {
    await pump(tester);

    await tester.tap(find.text('11:30 pm – 11:45 pm'));
    await tester.pumpAndSettle();

    expect(find.text('11:30 pm – 11:45 pm'), findsOneWidget);
    // Selecting does not re-ask the server: the list already said what is open.
    expect(repo.calls.where((c) => c.startsWith('slots')), hasLength(1));
  });

  testWidgets('a closed day shows the store\'s own message and no chips',
      (tester) async {
    repo.slotsByType = {
      OrderTypeKind.delivery: slotsFromFixture('slots_closed'),
    };
    await pump(tester);

    expect(
      find.text('We are closed on this day. Please choose another date.'),
      findsOneWidget,
    );
    expect(find.text('ASAP (20–35 min)'), findsNothing);
  });

  testWidgets('a dish not served then blocks the slot and names itself',
      (tester) async {
    repo.slotsByType = {
      OrderTypeKind.delivery: slotsFromFixture('slots_blocked'),
    };
    await pump(tester);

    await tester.tap(find.text('11:30 pm'));
    await tester.pump();

    expect(find.text('Margherita is not served at this time.'), findsOneWidget);
  });

  testWidgets('a store taking no orders says so instead of drawing a switch',
      (tester) async {
    repo.types = OrderTypes.fromJson({
      'types': [
        {'type': 'pickup', 'label': 'Pickup', 'enabled': false},
        {'type': 'delivery', 'label': 'Delivery', 'enabled': false},
      ],
    });
    await pump(tester);

    expect(
      find.textContaining('not taking pickup or delivery orders'),
      findsOneWidget,
    );
    expect(find.text('Pickup'), findsNothing);
  });

  testWidgets('a pickup-only store gets one pill, not half a dead switch',
      (tester) async {
    repo.types = OrderTypes.fromJson({
      'types': [
        {'type': 'pickup', 'label': 'Pickup', 'enabled': true, 'time_required': true},
        {'type': 'delivery', 'label': 'Delivery', 'enabled': false},
      ],
    });
    repo.slotsByType = {
      OrderTypeKind.pickup: slotsFromFixture('slots_pickup'),
    };
    await pump(tester);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Delivery'), findsNothing);
    expect(find.text('ASAP (15 min)'), findsOneWidget);
  });

  testWidgets('no required time draws the single ASAP row', (tester) async {
    repo.slotsByType = {
      OrderTypeKind.delivery: slotsFromFixture('slots_asap_only'),
    };
    await pump(tester);

    expect(find.text('ASAP (15 min)'), findsOneWidget);
    expect(find.textContaining('No times'), findsNothing);
  });

  testWidgets('a failed load offers a retry that asks again', (tester) async {
    repo.failNext = const ApiException(
      failure: ApiFailure.network,
      message: 'No connection.',
    );
    await pump(tester);

    expect(find.text('No connection.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('an empty cart is told so rather than offered times',
      (tester) async {
    cartRepo = FakeCartRepository();
    await pump(tester);

    expect(find.text('Your cart is empty.'), findsOneWidget);
    expect(find.text('Delivery'), findsNothing);
  });

  testWidgets('a long slot label does not overflow a narrow phone',
      (tester) async {
    // A delivery label is a window — "11:00 pm – 11:15 pm" — which is wider
    // than a 320pt screen has room for beside another. The row scrolls, so
    // every chip keeps its natural width and none of them overflow.
    await pump(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    for (final label in [
      'ASAP (20–35 min)',
      '11:00 pm – 11:15 pm',
      '11:15 pm – 11:30 pm',
      '11:30 pm – 11:45 pm',
      '11:45 pm – 11:59 pm',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}

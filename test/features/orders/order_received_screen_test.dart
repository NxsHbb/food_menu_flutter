import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/presentation/order_received_screen.dart';
import 'package:go_router/go_router.dart';

import 'fake_orders_repository.dart';

void main() {
  late FakeOrdersRepository repo;

  setUp(() => repo = FakeOrdersRepository());

  Future<void> pump(
    WidgetTester tester, {
    int orderId = 62,
    ThemeData? theme,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/order-received/$orderId',
      routes: [
        GoRoute(
          path: OrderReceivedScreen.routePath,
          name: OrderReceivedScreen.routeName,
          builder: (_, state) => OrderReceivedScreen(
            orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
          ),
        ),
        GoRoute(
          path: '/',
          name: 'menu',
          builder: (_, _) => const Scaffold(body: Text('Menu')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reads the order back by id rather than being told it',
      (tester) async {
    await pump(tester, orderId: 62);

    expect(repo.requested, [62]);
  });

  testWidgets('draws the design\'s three facts', (tester) async {
    await pump(tester);

    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.text('#62'), findsOneWidget);
    // The store's own word for the type, over its own estimate.
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('ASAP (20–35 min)'), findsOneWidget);
    expect(find.text('\$3.95'), findsOneWidget);
  });

  testWidgets('thanks the customer by the name on the order', (tester) async {
    await pump(tester);

    // The order's name, not the session's: the order is what the kitchen
    // works from.
    expect(
      find.textContaining('Thanks, Test.'),
      findsOneWidget,
    );
  });

  testWidgets('a pickup order shows the time that was chosen', (tester) async {
    repo.answer = orderFromFixture('order_pickup');
    await pump(tester, orderId: 60);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('6:45 am'), findsOneWidget);
  });

  testWidgets('an order with no name is still greeted', (tester) async {
    repo.answer = CustomerOrder.fromJson(const {
      'id': 70,
      'number': '70',
      'customer': {'name': ''},
      'totals': {'total_price': '0'},
    });
    await pump(tester, orderId: 70);

    expect(find.textContaining('The kitchen has your order'), findsOneWidget);
    expect(find.textContaining('Thanks,'), findsNothing);
  });

  testWidgets('an order with no estimate shows a dash, not a blank',
      (tester) async {
    repo.answer = CustomerOrder.fromJson(const {
      'id': 71,
      'number': '71',
      'eta': '',
      'totals': {'total_price': '0'},
    });
    await pump(tester, orderId: 71);

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('home leaves for the menu', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsOneWidget);
  });

  group('when it cannot be read', () {
    setUp(() {
      repo.failNext = const ApiException(
        failure: ApiFailure.network,
        message: 'No connection.',
      );
    });

    testWidgets('never says the order failed', (tester) async {
      // It was placed — the checkout answered with it. The worst case here is
      // that the customer cannot see it yet.
      await pump(tester);

      expect(find.text('Your order is placed'), findsOneWidget);
      expect(find.text('No connection.'), findsOneWidget);
    });

    testWidgets('offers a retry that asks again', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Order placed!'), findsOneWidget);
      expect(repo.requested, [62, 62]);
    });

    testWidgets('and a way home', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Back to home'));
      await tester.pumpAndSettle();

      expect(find.text('Menu'), findsOneWidget);
    });
  });

  testWidgets('renders in dark mode without error', (tester) async {
    await pump(tester, theme: AppTheme.dark());

    expect(tester.takeException(), isNull);
    expect(find.text('Order placed!'), findsOneWidget);
  });

  testWidgets('fits a narrow phone without overflowing', (tester) async {
    // Three tiles side by side, one of them holding "ASAP (20–35 min)".
    await pump(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(find.text('ASAP (20–35 min)'), findsOneWidget);
  });
}

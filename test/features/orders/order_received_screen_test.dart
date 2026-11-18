import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/presentation/order_detail_screen.dart';
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
    // Task 12.2: what the checkout hands over for a gateway that finishes in
    // a browser. Null everywhere else, as a cold open of this route is.
    String? payUrl,
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
            payUrl: payUrl,
          ),
        ),
        GoRoute(
          path: '/',
          name: 'menu',
          builder: (_, _) => const Scaffold(body: Text('Menu')),
        ),
        GoRoute(
          path: '/order/:id',
          name: OrderDetailScreen.routeName,
          builder: (_, state) =>
              Scaffold(body: Text('tracking ${state.pathParameters['id']}')),
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

  testWidgets('reads the order back by id rather than being told it', (
    tester,
  ) async {
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
    expect(find.textContaining('Thanks, Test.'), findsOneWidget);
  });

  testWidgets('a pickup order shows the time that was chosen', (tester) async {
    repo.answer = orderFromFixture('order_pickup');
    await pump(tester, orderId: 60);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('6:45 am'), findsOneWidget);
    // And the day it was chosen for: since task 8.4 that can be days out,
    // and a bare "6:45 am" then reads as this morning.
    expect(find.text('November 10, 2026'), findsOneWidget);
  });

  testWidgets('an ASAP order is not dated', (tester) async {
    repo.answer = CustomerOrder.fromJson({
      ...jsonFixture('order_pickup'),
      // The plugin stores no time for an ASAP order, and the date it does
      // store is simply the day it was placed.
      'time': '',
      'eta': 'ASAP (15 min)',
    });
    await pump(tester, orderId: 60);

    expect(find.text('ASAP (15 min)'), findsOneWidget);
    expect(find.text('November 10, 2026'), findsNothing);
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

  testWidgets('an order with no estimate shows a dash, not a blank', (
    tester,
  ) async {
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

  testWidgets('track order opens the order it just placed', (tester) async {
    await pump(tester, orderId: 62);

    await tester.tap(find.text('Track order'));
    await tester.pumpAndSettle();

    // Navigates into the Orders tab rather than pushing, so backing out of
    // the order lands on the history and not on a receipt for an order
    // already placed.
    expect(find.text('tracking 62'), findsOneWidget);
  });

  testWidgets('back to home is still there, and secondary', (tester) async {
    await pump(tester);

    // The design makes tracking the primary action: what a customer who has
    // just ordered wants next is to watch it being made.
    expect(find.widgetWithText(FilledButton, 'Track order'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Back to home'), findsOneWidget);
  });

  group('payment instructions (task 12.1)', () {
    testWidgets('a bank-transfer order is told how to pay', (tester) async {
      repo.answer = orderFromFixture('order_bank_transfer');
      await pump(tester, orderId: 60);

      expect(find.text('How to pay'), findsOneWidget);
      expect(find.textContaining('quote your order number'), findsOneWidget);
      // The rows the customer actually needs to move money.
      expect(find.text('Account number'), findsOneWidget);
      expect(find.text('0012345678901'), findsOneWidget);
    });

    testWidgets('and is not told the kitchen has started', (tester) async {
      repo.answer = orderFromFixture('order_bank_transfer');
      await pump(tester, orderId: 60);

      expect(
        find.textContaining('as soon as your payment arrives'),
        findsOneWidget,
      );
      expect(find.textContaining('getting started'), findsNothing);
    });

    testWidgets('a cash order still says the kitchen has it', (tester) async {
      await pump(tester);

      expect(find.textContaining('getting started'), findsOneWidget);
      expect(find.text('How to pay'), findsNothing);
    });

    testWidgets('the card survives a large text scale', (tester) async {
      // Task 14.9's rule: the bank rows are the one block on this screen a
      // customer has to read off a phone, and they are long strings.
      repo.answer = orderFromFixture('order_bank_transfer');
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(tester, orderId: 60);

      expect(tester.takeException(), isNull);
      expect(find.text('How to pay'), findsOneWidget);
    });
  });

  group('a gateway that finishes in a browser (task 12.2)', () {
    const payUrl = 'https://example.test/checkout/order-pay/62/?key=wc_order_x';

    testWidgets('says the payment is unfinished, not that it is placed',
        (tester) async {
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);

      expect(find.text('Finish your payment'), findsOneWidget);
      // The lie task 12.1 took out of the bank-transfer case.
      expect(find.text('Order placed!'), findsNothing);
      expect(find.textContaining('Card / UPI / Net banking'), findsOneWidget);
    });

    testWidgets('offers to pay, to recheck, and to leave', (tester) async {
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);

      expect(find.text('Pay now'), findsOneWidget);
      // For the customer who paid somewhere this app cannot see.
      expect(find.text('I have already paid'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
    });

    testWidgets('a paid order is a placed order', (tester) async {
      // Same route, same redirect — the order is what decides, not the URL.
      await pump(tester, payUrl: payUrl);

      expect(find.text('Order placed!'), findsOneWidget);
      expect(find.text('Finish your payment'), findsNothing);
    });

    testWidgets('a cold open never reopens the gateway', (tester) async {
      // No `payUrl`: reopening the screen from a notification or a restored
      // stack must show the order, not send the customer back to pay.
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester);

      expect(find.text('Finish your payment'), findsNothing);
      expect(find.text('Order placed!'), findsOneWidget);
    });

    testWidgets('rechecking reads the order again', (tester) async {
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);
      expect(repo.requested, [62]);

      await tester.tap(find.text('I have already paid'));
      await tester.pumpAndSettle();

      expect(repo.requested, [62, 62]);
    });

    testWidgets('and so does coming back into the app', (tester) async {
      // The only signal an in-app browser view gives: neither a Custom Tab
      // nor SFSafariViewController reports the URL it ended on.
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);
      expect(repo.requested, [62]);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(repo.requested.length, greaterThan(1));
    });

    testWidgets('the paid order replaces the waiting state in place',
        (tester) async {
      // Task 14.8's rule on this screen: invalidating leaves the provider
      // loading *while holding* its last value, so matching loading first
      // would flash a spinner every time the customer came back.
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);
      expect(find.text('Finish your payment'), findsOneWidget);

      repo.answer = orderFromFixture('order_delivery');
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Order placed!'), findsOneWidget);
    });
  });
}

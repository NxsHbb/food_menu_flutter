import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/presentation/order_detail_screen.dart';
import 'package:food_menu/src/features/checkout/presentation/payment_webview_screen.dart';
import 'package:food_menu/src/features/orders/presentation/order_received_screen.dart';
import 'package:go_router/go_router.dart';

import 'fake_orders_repository.dart';

void main() {
  late FakeOrdersRepository repo;

  /// Every push to the payment screen, in order (task 12.4).
  late List<({String url, String title})?> opened;

  setUp(() {
    repo = FakeOrdersRepository();
    opened = [];
  });

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
        // Task 12.4's screen is a platform webview, which a widget test
        // cannot build. What matters here is that the screen pushes it, and
        // with what — so this stands in and says so.
        GoRoute(
          path: PaymentWebViewScreen.routePath,
          name: PaymentWebViewScreen.routeName,
          builder: (context, state) {
            final args = state.extra as ({String url, String title})?;
            opened.add(args);
            return Scaffold(
              body: Column(
                children: [
                  Text('Gateway: ${args?.title}'),
                  // Stands in for the real screen's header back and for the
                  // webview closing itself on the return URL.
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close gateway'),
                  ),
                ],
              ),
            );
          },
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

  group('a gateway that finishes in a browser (tasks 12.2, 12.4)', () {
    const payUrl = 'https://example.test/checkout/order-pay/62/?key=wc_order_x';

    /// Opens the screen on an unpaid order and comes back from the gateway,
    /// which is where the customer is after paying, cancelling, or pressing
    /// back.
    Future<void> returnFromGateway(WidgetTester tester) async {
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);
      await tester.tap(find.text('Close gateway'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the gateway inside the app, named', (tester) async {
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);

      // Task 12.4: the app's own screen, not a browser handed the URL.
      expect(opened.single?.url, payUrl);
      // The merchant's own name for the gateway, as everywhere else.
      expect(opened.single?.title, 'Card / UPI / Net banking');
      expect(find.text('Gateway: Card / UPI / Net banking'), findsOneWidget);
    });

    testWidgets('coming back says the payment is unfinished', (tester) async {
      await returnFromGateway(tester);

      expect(find.text('Finish your payment'), findsOneWidget);
      // The lie task 12.1 took out of the bank-transfer case.
      expect(find.text('Order placed!'), findsNothing);
      expect(find.textContaining('Card / UPI / Net banking'), findsOneWidget);
    });

    testWidgets('and offers to pay, to recheck, and to leave', (tester) async {
      await returnFromGateway(tester);

      expect(find.text('Pay now'), findsOneWidget);
      // For the customer who paid somewhere this app cannot see.
      expect(find.text('I have already paid'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
    });

    testWidgets('coming back re-reads the order', (tester) async {
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester, payUrl: payUrl);
      final before = repo.requested.length;

      await tester.tap(find.text('Close gateway'));
      await tester.pumpAndSettle();

      expect(repo.requested.length, greaterThan(before));
    });

    testWidgets('a paid order never opens the gateway', (tester) async {
      // Same route, same redirect — the order is what decides.
      await pump(tester, payUrl: payUrl);

      expect(opened, isEmpty);
      expect(find.text('Order placed!'), findsOneWidget);
    });

    testWidgets('a cold open never opens the gateway', (tester) async {
      // No `payUrl`: reopening from a notification or a restored stack must
      // show the order, not send the customer back to pay.
      repo.answer = orderFromFixture('order_awaiting_payment');
      await pump(tester);

      expect(opened, isEmpty);
      expect(find.text('Order placed!'), findsOneWidget);
    });

    testWidgets('rechecking reads the order again', (tester) async {
      await returnFromGateway(tester);
      final before = repo.requested.length;

      await tester.tap(find.text('I have already paid'));
      await tester.pumpAndSettle();

      expect(repo.requested.length, before + 1);
    });

    testWidgets('and so does coming back into the app', (tester) async {
      // The backstop for a gateway that sent the customer to a banking app:
      // the webview is gone and only the lifecycle says they are back.
      await returnFromGateway(tester);
      final before = repo.requested.length;

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(repo.requested.length, greaterThan(before));
    });

    testWidgets('the paid order replaces the waiting state in place',
        (tester) async {
      // Task 14.8's rule on this screen: invalidating leaves the provider
      // loading *while holding* its last value, so matching loading first
      // would flash a spinner every time the customer came back.
      await returnFromGateway(tester);
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

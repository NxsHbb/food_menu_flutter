import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/presentation/order_detail_screen.dart';
import 'package:food_menu/src/features/orders/presentation/orders_screen.dart';
import 'package:food_menu/src/features/orders/presentation/widgets/order_status_pill.dart';
import 'package:go_router/go_router.dart';

import 'fake_orders_repository.dart';

void main() {
  late FakeOrdersRepository repo;

  setUp(() => repo = FakeOrdersRepository());

  Future<void> pump(WidgetTester tester, {int id = 64}) async {
    final router = GoRouter(
      initialLocation: '/order/$id',
      routes: [
        GoRoute(
          path: '/',
          name: OrdersScreen.routeName,
          builder: (_, _) => const Scaffold(body: Text('the history')),
        ),
        GoRoute(
          path: '/order/:id',
          name: OrderDetailScreen.routeName,
          builder: (_, state) => OrderDetailScreen(
            orderId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reads the order it was routed to', (tester) async {
    await pump(tester, id: 64);

    expect(repo.requested, [64]);
  });

  testWidgets('heads the screen with the number and status', (tester) async {
    await pump(tester);

    expect(
      find.text('Order #${repo.answer.number}'),
      findsOneWidget,
    );
    expect(find.byType(OrderStatusPill), findsOneWidget);
    expect(find.text(repo.answer.statusLabel), findsOneWidget);
  });

  testWidgets('lists every line with its quantity', (tester) async {
    await pump(tester);

    for (final item in repo.answer.items) {
      expect(find.text('${item.quantity}× ${item.name}'), findsOneWidget);
    }
  });

  testWidgets('shows the total the order was charged', (tester) async {
    await pump(tester);

    // Against the "Total" label specifically: on a one-line order the
    // subtotal, the line and the total are the same number three times over,
    // so a bare text match would pass without the row existing at all.
    final totalRow = find
        .ancestor(of: find.text('Total'), matching: find.byType(Row))
        .first;

    expect(
      find.descendant(
        of: totalRow,
        matching: find.text(repo.answer.totals.totalPrice.format()),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a zero fee or tax line is left out rather than shown as zero',
      (tester) async {
    await pump(tester);

    // The fixture is a plain cash order: nothing but a subtotal and a total,
    // and rows of "$0.00" would be noise.
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Tax'), findsNothing);
    expect(find.text('Fees'), findsNothing);
  });

  testWidgets('names the payment method', (tester) async {
    await pump(tester);

    expect(
      find.text(repo.answer.paymentMethodTitle),
      findsOneWidget,
    );
  });

  testWidgets('neither tracking nor reorder is pretended at', (tester) async {
    await pump(tester);

    // Both are deliberately absent: the timeline needs the tracking route
    // (task 7.3), and a faithful reorder needs the plugin to record a
    // re-submittable add-on selection. A button for either would be a
    // stand-in, which is what task 4.7 existed to clean up.
    expect(find.text('Reorder'), findsNothing);
    expect(find.textContaining('Track'), findsNothing);
  });

  testWidgets('a failure offers a retry and a way back', (tester) async {
    repo.failNext = const ApiException(
      failure: ApiFailure.network,
      message: 'Could not reach the server.',
    );
    await pump(tester);

    expect(find.text('Could not reach the server.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Order #${repo.answer.number}'), findsOneWidget);
  });

  testWidgets('a 404 offers no retry, because there is nothing to retry',
      (tester) async {
    // The plugin answers somebody else's order exactly as a missing one, so
    // retrying would ask the same unanswerable question again.
    repo.failNext = const ApiException(
      failure: ApiFailure.http,
      message: 'That order could not be found.',
      statusCode: 404,
      code: 'fmp_app_order_not_found',
    );
    await pump(tester);

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Back to orders'), findsOneWidget);
  });

  testWidgets('back lands on the history when there is nothing to pop',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('the history'), findsOneWidget);
  });

  testWidgets('renders in dark mode without error', (tester) async {
    final router = GoRouter(
      initialLocation: '/order/64',
      routes: [
        GoRoute(
          path: '/order/:id',
          name: OrderDetailScreen.routeName,
          builder: (_, _) => const OrderDetailScreen(orderId: 64),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('the status pill', () {
    testWidgets('takes the colour the store chose', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: OrderStatusPill(label: 'In the oven', color: '#2563eb'),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('In the oven'));
      expect(text.style?.color, const Color(0xff2563eb));
    });

    testWidgets('falls back to the theme for a colour it cannot read',
        (tester) async {
      // Better plain than arbitrary: a status being read must not be painted
      // in whatever a malformed string happens to parse to.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: OrderStatusPill(label: 'Unknown', color: 'not a colour'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Unknown'), findsOneWidget);
    });
  });

  group('parseHexColor', () {
    test('reads six digits, with or without the hash', () {
      expect(parseHexColor('#16a34a'), const Color(0xff16a34a));
      expect(parseHexColor('16a34a'), const Color(0xff16a34a));
    });

    test('refuses anything else', () {
      // Eight digits is CSS's #rrggbbaa, which Color(int) would read as
      // 0xaarrggbb — the wrong colour, confidently.
      expect(parseHexColor('#16a34aff'), isNull);
      expect(parseHexColor('#abc'), isNull);
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#zzzzzz'), isNull);
    });
  });
}

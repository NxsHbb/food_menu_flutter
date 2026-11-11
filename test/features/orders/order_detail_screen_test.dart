import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/presentation/order_detail_screen.dart';
import 'package:food_menu/src/features/orders/presentation/orders_screen.dart';
import 'package:food_menu/src/features/orders/presentation/widgets/order_progress_bar.dart';
import 'package:food_menu/src/features/orders/presentation/widgets/reorder_button.dart';
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
    // Scoped to the pill: the tracking card names the current stage too, and
    // on most orders that is the same word as the status.
    expect(
      find.descendant(
        of: find.byType(OrderStatusPill),
        matching: find.text(repo.answer.statusLabel),
      ),
      findsOneWidget,
    );
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

    // Below the fold since the tracking card went in above it, and the body
    // is a lazy ListView — so it has to be scrolled to rather than found.
    await tester.scrollUntilVisible(
      find.text(repo.answer.paymentMethodTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text(repo.answer.paymentMethodTitle),
      findsOneWidget,
    );
  });

  testWidgets('an active order offers no reorder', (tester) async {
    await pump(tester);

    // The fixture is still processing. Reordering something being cooked is
    // how a customer ends up with two dinners.
    expect(find.byType(ReorderButton), findsNothing);
  });

  testWidgets('a finished order offers reorder in the footer', (tester) async {
    repo.answer = CustomerOrder.fromJson({
      ...jsonFixture('order_delivery'),
      'status': 'completed',
      'status_label': 'Completed',
      'is_active': false,
    });
    await pump(tester);

    expect(find.byType(ReorderButton), findsOneWidget);
    // The footer's primary action, as the design draws it.
    expect(find.widgetWithText(FilledButton, 'Reorder'), findsOneWidget);
  });

  group('the tracking card', () {
    testWidgets('reads tracking separately from the order', (tester) async {
      await pump(tester, id: 64);

      // Two requests on purpose: the order is settled, its progress is the
      // one part that moves.
      expect(repo.requested, [64]);
      expect(repo.trackingRequested, [64]);
    });

    testWidgets('draws the estimate while the order is active',
        (tester) async {
      await pump(tester);

      // "Arriving", not the design's "Arriving in": the plugin's estimate can
      // be the literal word ASAP, and "Arriving in ASAP" does not read.
      expect(find.text('Arriving'), findsOneWidget);
      expect(find.text(repo.answer.eta), findsOneWidget);
    });

    testWidgets('a pickup order is ready rather than arriving',
        (tester) async {
      repo.answer = orderFromFixture('order_pickup');
      // A pipeline with no stage called "Ready", so the only match is the
      // estimate's own title.
      repo.trackingAnswer = trackingFixture(
        stages: const [
          ('processing', 'Processing', true),
          ('completed', 'Completed', false),
        ],
      );
      await pump(tester);

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Arriving'), findsNothing);
    });

    testWidgets('a finished order claims no estimate', (tester) async {
      repo.answer = CustomerOrder.fromJson({
        ...jsonFixture('order_delivery'),
        'status': 'completed',
        'status_label': 'Completed',
        'is_active': false,
      });
      repo.trackingAnswer = trackingFixture(
        status: 'completed',
        statusLabel: 'Completed',
        isActive: false,
        stages: const [
          ('processing', 'Processing', true),
          ('completed', 'Completed', true),
        ],
      );
      await pump(tester);

      // "Arriving ASAP" on a delivered order would be a claim about food that
      // already came. The timeline still draws.
      expect(find.text('Arriving'), findsNothing);
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('lists every stage, reached and still to come',
        (tester) async {
      repo.trackingAnswer = trackingFixture(note: 'Kitchen has it');
      await pump(tester);

      for (final stage in repo.trackingAnswer.stages) {
        expect(find.text(stage.label), findsWidgets);
      }
      // The store's note and its own formatted time, which the app does not
      // re-zone onto the phone's clock.
      expect(find.text('Kitchen has it'), findsOneWidget);
      expect(find.text('November 10, 2026 at 8:59 am'), findsWidgets);
    });

    testWidgets('a failed tracking request costs the timeline, not the screen',
        (tester) async {
      repo.failNextTracking = const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server.',
      );
      await pump(tester);

      // The order is still worth drawing, and the estimate comes from it.
      expect(find.text('Order #${repo.answer.number}'), findsOneWidget);
      expect(find.text('Arriving'), findsOneWidget);
      expect(
        find.text('Progress for this order could not be loaded.'),
        findsOneWidget,
      );
    });

    testWidgets('says so when the store keeps no history', (tester) async {
      repo.trackingAnswer = trackingFixture(
        hasTimeline: false,
        stages: const [],
      );
      await pump(tester);

      expect(find.text('This order has no progress history.'), findsOneWidget);
      expect(find.byType(OrderProgressBar), findsNothing);
    });

    testWidgets('a cancelled order shows an empty strip', (tester) async {
      repo.trackingAnswer = trackingFixture(
        status: 'cancelled',
        statusLabel: 'Cancelled',
        isActive: false,
        isFailed: true,
        stages: const [
          ('processing', 'Processing', true),
          ('cancelled', 'Cancelled', true),
        ],
      );
      await pump(tester);

      final bar = tester.widget<OrderProgressBar>(
        find.byType(OrderProgressBar),
      );
      expect(bar.dimmed, isTrue);
    });
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

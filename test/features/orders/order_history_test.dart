import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/network/api_exception.dart';
import 'package:food_menu/src/core/theme/app_theme.dart';
import 'package:food_menu/src/features/auth/data/auth_controller.dart';
import 'package:food_menu/src/features/auth/data/auth_repository.dart';
import 'package:food_menu/src/features/auth/data/token_store.dart';
import 'package:food_menu/src/features/orders/data/orders_repository.dart';
import 'package:food_menu/src/features/orders/presentation/order_detail_screen.dart';
import 'package:food_menu/src/features/orders/presentation/orders_screen.dart';
import 'package:food_menu/src/features/orders/presentation/widgets/order_progress_bar.dart';
import 'package:food_menu/src/features/orders/presentation/widgets/order_row.dart';
import 'package:go_router/go_router.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_orders_repository.dart';

void main() {
  late FakeOrdersRepository repo;

  setUp(() => repo = FakeOrdersRepository());

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool signedIn = true,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: OrdersScreen.routeName,
          builder: (_, _) => const OrdersScreen(),
          routes: [
            GoRoute(
              path: 'order/:id',
              name: OrderDetailScreen.routeName,
              builder: (_, state) => Scaffold(
                body: Text('detail ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        tokenStoreProvider.overrideWithValue(FakeTokenStore()),
      ],
    );
    addTearDown(container.dispose);

    // An order history belongs to an account, so every one of these tests is
    // about a signed-in customer unless it says otherwise.
    if (signedIn) {
      await container
          .read(authControllerProvider.notifier)
          .login(username: 'customer@foodmenu.test', password: 'pw');
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('the list', () {
    testWidgets('opens on Active', (tester) async {
      repo.history[OrderGroup.active] = [summaryFixture(id: 1048)];
      await pump(tester);

      expect(repo.historyCalls.single.group, OrderGroup.active);
      expect(find.text('Order #1048'), findsOneWidget);
    });

    testWidgets('labels the tab with the count the server reported',
        (tester) async {
      repo.history[OrderGroup.active] = [
        for (var i = 0; i < 7; i++) summaryFixture(id: 1000 + i),
      ];
      await pump(tester);

      expect(find.text('Active (7)'), findsOneWidget);
    });

    testWidgets('a row carries the number, date, type, count and total',
        (tester) async {
      repo.history[OrderGroup.active] = [
        summaryFixture(
          id: 1048,
          itemCount: 3,
          total: '1995',
          createdAt: DateTime.now(),
        ),
      ];
      await pump(tester);

      expect(find.text('Order #1048'), findsOneWidget);
      expect(find.textContaining('Delivery'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);
      expect(find.text(r'$19.95'), findsOneWidget);
    });

    testWidgets('one item is singular', (tester) async {
      repo.history[OrderGroup.active] = [summaryFixture(itemCount: 1)];
      await pump(tester);

      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('an active row shows its status and estimate', (tester) async {
      repo.history[OrderGroup.active] = [
        summaryFixture(statusLabel: 'Processing', eta: '20–35 min'),
      ];
      await pump(tester);

      expect(find.text('ETA 20–35 min'), findsOneWidget);
    });

    testWidgets('a pickup order is ready rather than arriving', (tester) async {
      repo.history[OrderGroup.active] = [
        summaryFixture(type: 'pickup', typeLabel: 'Pickup', eta: '15 min'),
      ];
      await pump(tester);

      expect(find.text('Ready 15 min'), findsOneWidget);
    });

    testWidgets('a finished row has no estimate strip', (tester) async {
      repo.history[OrderGroup.past] = [
        summaryFixture(
          status: 'completed',
          statusLabel: 'Completed',
          isActive: false,
          eta: '20 min',
        ),
      ];
      await pump(tester);
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      // The eta is still in the payload; a finished order just has no use
      // for it, and showing one would read as still coming.
      expect(find.textContaining('ETA'), findsNothing);
    });

    testWidgets('an active row draws the strip the server measured',
        (tester) async {
      repo.history[OrderGroup.active] = [
        summaryFixture(progress: const {'step': 1, 'stage_count': 4}),
      ];
      await pump(tester);

      final bar = tester.widget<OrderProgressBar>(
        find.byType(OrderProgressBar),
      );
      // One third along, from the server's own pair — never counted here, and
      // never guessed from the status slug.
      expect(bar.fraction, closeTo(1 / 3, 0.001));
      expect(bar.dimmed, isFalse);
    });

    testWidgets('a row with no progress has no strip at all', (tester) async {
      // The store keeps no timeline, or the order predates it. A bar stuck at
      // the left would read as an order nobody has started.
      repo.history[OrderGroup.active] = [summaryFixture()];
      await pump(tester);

      expect(find.byType(OrderProgressBar), findsNothing);
      // The estimate still shows: it does not come from the timeline.
      expect(find.textContaining('ETA'), findsOneWidget);
    });

    testWidgets('a row with neither strip nor estimate has no footer',
        (tester) async {
      repo.history[OrderGroup.active] = [summaryFixture(eta: '')];
      await pump(tester);

      expect(find.byType(OrderProgressBar), findsNothing);
      expect(find.textContaining('ETA'), findsNothing);
      // No divider either, rather than one over an empty row.
      expect(
        find.descendant(of: find.byType(OrderRow), matching: find.byType(Divider)),
        findsNothing,
      );
    });

    testWidgets('tapping a row opens that order', (tester) async {
      repo.history[OrderGroup.active] = [summaryFixture(id: 1048)];
      await pump(tester);

      await tester.tap(find.byType(OrderRow));
      await tester.pumpAndSettle();

      expect(find.text('detail 1048'), findsOneWidget);
    });
  });

  group('the tabs', () {
    testWidgets('switching asks the server for the other group',
        (tester) async {
      repo.history[OrderGroup.active] = [summaryFixture(id: 1)];
      repo.history[OrderGroup.past] = [
        summaryFixture(id: 2, isActive: false, status: 'completed'),
      ];
      await pump(tester);

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      expect(repo.historyCalls.last.group, OrderGroup.past);
      expect(find.text('Order #2'), findsOneWidget);
      // Rebuilt, not appended to: the active order is gone from the list.
      expect(find.text('Order #1'), findsNothing);
    });

    testWidgets('tapping the selected tab asks nothing further',
        (tester) async {
      repo.history[OrderGroup.active] = [summaryFixture()];
      await pump(tester);

      await tester.tap(find.textContaining('Active'));
      await tester.pumpAndSettle();

      expect(repo.historyCalls, hasLength(1));
    });

    testWidgets('an empty tab says which one it is', (tester) async {
      await pump(tester);

      expect(find.text('No active orders'), findsOneWidget);

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      expect(find.text('No past orders'), findsOneWidget);
    });
  });

  group('signed out', () {
    testWidgets('invites a sign-in rather than failing', (tester) async {
      await pump(tester, signedIn: false);

      expect(find.text('Your orders'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      // Nothing was asked for: a 401 with a "Try again" that cannot work is
      // the wrong answer to "you are not signed in".
      expect(repo.historyCalls, isEmpty);
      // And the tabs are meaningless with nothing to list.
      expect(find.text('Past'), findsNothing);
    });
  });

  group('failures', () {
    testWidgets('a failed load offers a retry that asks again',
        (tester) async {
      repo.failNextHistory = const ApiException(
        failure: ApiFailure.network,
        message: 'Could not reach the server.',
      );
      repo.history[OrderGroup.active] = [summaryFixture(id: 1048)];
      await pump(tester);

      expect(find.text('Could not reach the server.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Order #1048'), findsOneWidget);
    });
  });
}

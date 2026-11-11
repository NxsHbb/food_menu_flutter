import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../menu/presentation/menu_screen.dart';
import '../data/orders_repository.dart';
import '../domain/customer_order.dart';
import 'order_detail_screen.dart';

/// The design's order-received screen.
///
/// **Everything on it is read back from the server**, by id, rather than
/// carried over from the checkout's answer. Two reasons: the checkout
/// response echoes the plugin's extension schema with its defaults instead of
/// the saved order, so the time the customer chose is not in it; and a store
/// can renumber, reprice or re-status an order between the post and the
/// screen. Reading it back also makes the route survive being opened cold.
///
/// The design's "Track order" button opens the order screen, which task 7.3
/// gave the estimate, the progress strip and the timeline. It navigates into
/// the Orders tab rather than pushing, so backing out of the order lands on
/// the history list instead of on a receipt for an order already placed.
class OrderReceivedScreen extends ConsumerWidget {
  const OrderReceivedScreen({required this.orderId, super.key});

  final int orderId;

  static const routePath = '/order-received/:id';
  static const routeName = 'order-received';

  /// Where this screen goes next. The cart is gone and the checkout behind it
  /// is for an order already placed, so there is nothing to go back to.
  static void _home(BuildContext context) =>
      context.goNamed(MenuScreen.routeName);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final order = ref.watch(orderProvider(orderId));

    return PopScope(
      // Back is "home", not "out of the app": this route replaces the stack,
      // so there is nothing beneath it to pop to.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context);
      },
      child: Scaffold(
        backgroundColor: palette.card,
        body: SafeArea(
          child: switch (order) {
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncError(:final error) => _Unreadable(
              error: error,
              onRetry: () => ref.invalidate(orderProvider(orderId)),
              onHome: () => _home(context),
            ),
            AsyncData(:final value) => _Placed(order: value),
          },
        ),
      ),
    );
  }
}

class _Placed extends StatelessWidget {
  const _Placed({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final name = order.firstName;

    return Column(
      children: [
        Expanded(
          // Centred when it fits and scrollable when it does not — a short
          // phone, or a large text scale, otherwise clips the tiles.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space24,
                AppTokens.space24,
                AppTokens.space24,
                AppTokens.space16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight -
                      AppTokens.space24 -
                      AppTokens.space16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Tick(),
                    const SizedBox(height: AppTokens.space20),
                    Text(
                      'Order placed!',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Text(
                      // The name is the one on the order, not the one in the
                      // session: the order is what the kitchen works from.
                      name.isEmpty
                          ? 'The kitchen has your order and is getting '
                                'started.'
                          : 'Thanks, $name. The kitchen has your order and '
                                'is getting started.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    _Facts(order: order),
                  ],
                ),
              ),
            ),
          ),
        ),
        _Actions(
          onTrack: () => context.goNamed(
            OrderDetailScreen.routeName,
            pathParameters: {'id': '${order.id}'},
          ),
          onHome: () => OrderReceivedScreen._home(context),
        ),
      ],
    );
  }
}

/// The design's three tiles: the order, when it is due, and what it cost.
class _Facts extends StatelessWidget {
  const _Facts({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    // `IntrinsicHeight`, because the three tiles have to be equally tall and
    // a bare `stretch` inside the scroll view asks for infinite height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Fact(label: 'Order', value: '#${order.number}'),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: _Fact(
              // The store's own word for the type — "Pickup", "Delivery" —
              // over its own estimate, neither composed here.
              label: order.typeLabel.isEmpty ? 'Estimated' : order.typeLabel,
              value: order.eta.isEmpty ? '—' : order.eta,
              // Only for an order placed for another day, which the date
              // strip made possible: "12:00 am" alone reads as tonight.
              note: order.scheduledDate,
            ),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: _Fact(
              label: 'Total',
              value: order.totals.totalPrice.format(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.note = ''});

  final String label;
  final String value;

  /// A quieter line under the value. Empty on most tiles.
  final String note;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppTokens.space2),
          Text(
            value,
            maxLines: 2,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (note.isNotEmpty)
            Text(
              note,
              maxLines: 2,
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.tint, shape: BoxShape.circle),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: palette.brand, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 40, color: Colors.white),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onTrack, required this.onHome});

  final VoidCallback onTrack;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space12,
        AppTokens.space16,
        AppTokens.space24,
      ),
      child: Column(
        children: [
          // Primary, as the design has it: the next thing a customer who has
          // just ordered wants is to watch it being made.
          FilledButton(onPressed: onTrack, child: const Text('Track order')),
          const SizedBox(height: AppTokens.space8),
          TextButton(onPressed: onHome, child: const Text('Back to home')),
        ],
      ),
    );
  }
}

/// The order exists; this screen could not read it.
///
/// **Never says the order failed.** It was placed — the checkout answered
/// with it — so the worst case here is that the customer cannot see it yet.
class _Unreadable extends StatelessWidget {
  const _Unreadable({
    required this.error,
    required this.onRetry,
    required this.onHome,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Tick(),
            const SizedBox(height: AppTokens.space20),
            Text(
              'Your order is placed',
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              api?.message ?? 'We could not load its details just now.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: AppTokens.space8),
            TextButton(onPressed: onHome, child: const Text('Back to home')),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/capability/capability_probe.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/util/relative_date.dart';
import '../../../core/widgets/dish_image_placeholder.dart';
import '../data/orders_repository.dart';
import '../domain/customer_order.dart';
import '../domain/order_tracking.dart';
import 'orders_screen.dart';
import 'widgets/order_status_pill.dart';
import 'widgets/order_tracking_card.dart';
import 'widgets/reorder_button.dart';

/// One order in full — the design's "Order tracking" screen.
///
/// **Two requests, deliberately.** The order itself is settled: its items,
/// totals and address will not change. Its progress is the one part that
/// does, so the estimate card, the strip and the timeline read
/// `/app/orders/{id}/tracking` separately. A tracking failure then costs the
/// timeline rather than the screen — the rest of the order is still worth
/// drawing, and task 7.2 proved the screen stands without it.
///
/// **Reorder is on a finished order**, as the design's footer has it. The
/// plugin decides what can actually be reproduced — see `Reorder` — so the
/// button is offered on every past order and reports afterwards rather than
/// being withheld from orders it might have managed.
///
/// The design's other footer action is "Get help", which has no backend in v1
/// and is left out rather than stubbed.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  static const routePath = 'order/:id';
  static const routeName = 'orderDetail';

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      backgroundColor: palette.bg,
      body: switch (order) {
        // **The value is matched first, so a pull does not blank the
        // screen** (task 14.8). Refreshing puts the provider back into
        // `AsyncLoading` while it still holds the order it had, and
        // matching the state before the value would swap the whole screen
        // for a spinner under the customer's own thumb — the opposite of
        // what the pull asked for. The same reading keeps the order up when
        // a refresh *fails*: the snack bar reports that, rather than the
        // error page throwing away an order that is still perfectly good.
        AsyncValue(:final value?) => _Detail(
            // **The routed id, not `order.id`.** They are the same on a
            // store that numbers its orders by post id and are not on one
            // that does not, and a refresh keyed on the wrong one reloads a
            // provider nobody is watching: the indicator turns, a request
            // goes out for somebody else's order, and the screen never
            // changes. Caught by the test below rather than by a customer.
            orderId: orderId,
            order: value,
            // Null while it loads and after it fails. The card draws the
            // estimate from the order either way and says so for the rest.
            //
            // **Not even asked for on a store without the route** (task
            // 14.7). The provider is left unwatched rather than watched and
            // ignored, which is what keeps the request from being made.
            tracking: ref.watch(capabilitiesProvider).hasOrderTracking
                ? ref.watch(orderTrackingProvider(orderId)).value
                : null,
          ),
        AsyncError(:final error) => _DetailError(error: error, id: orderId),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Leaves the order screen.
///
/// A deep link can open the app *on* an order, where there is nothing to pop,
/// so that case lands on the history list instead of throwing.
void closeOrder(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed(OrdersScreen.routeName);
  }
}

/// Re-reads one order, and its progress where the store publishes it.
///
/// **Both, because the screen draws both.** The order carries the status pill
/// and the totals; `/app/orders/{id}/tracking` carries the timeline, and task
/// 7.3 kept them as two requests precisely so one can fail without the other.
/// The tracking is asked for **only where the store has the route** (task
/// 14.7): a pull must not make the request the screen itself declines to.
///
/// A failed refresh is **reported**, because the pull was an explicit ask and
/// an indicator that retracts leaving the same numbers reads as "nothing has
/// changed" rather than "that did not work". A failed *tracking* refresh is
/// not: it costs the timeline alone, which is task 7.3's whole reason for
/// splitting them, and the order on screen is still correct.
Future<void> _refresh(BuildContext context, WidgetRef ref, int orderId) async {
  final messenger = ScaffoldMessenger.of(context);
  final hasTracking = ref.read(capabilitiesProvider).hasOrderTracking;

  ref.invalidate(orderProvider(orderId));
  if (hasTracking) ref.invalidate(orderTrackingProvider(orderId));

  try {
    await ref.read(orderProvider(orderId).future);
  } on ApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return;
  }

  if (!hasTracking) return;

  try {
    await ref.read(orderTrackingProvider(orderId).future);
  } on Object {
    // Deliberately silent; see above.
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.orderId,
    required this.order,
    required this.tracking,
  });

  /// The id the screen was routed to, which is what the providers are keyed
  /// on. Not necessarily [CustomerOrder.id]; see the note where this is
  /// passed in.
  final int orderId;
  final CustomerOrder order;
  final OrderTracking? tracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          color: palette.card,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space12,
                AppTokens.space16,
                AppTokens.space14,
              ),
              child: Row(
                children: [
                  _BackButton(onTap: () => closeOrder(context)),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #${order.number}', style: text.titleLarge),
                        if (order.createdAt != null) ...[
                          const SizedBox(height: AppTokens.space2),
                          Text(
                            relativeDateTime(order.createdAt!),
                            style:
                                text.bodySmall?.copyWith(color: palette.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  OrderStatusPill(
                    label: order.statusLabel,
                    color: order.statusColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          // **The screen a customer sits on while the food is coming**, so
          // it is the one place a pull is worth most (task 14.8). The order
          // itself rarely moves; its status and its tracking do, and the
          // alternative was leaving the screen and coming back.
          child: RefreshIndicator(
            onRefresh: () => _refresh(context, ref, orderId),
            child: ListView(
              // So a short order — one dish, no note — can still be pulled.
              // Without this the list does not overscroll and the gesture
              // never reaches the indicator.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space14,
                AppTokens.space16,
                AppTokens.space24,
              ),
              children: [
                OrderTrackingCard(order: order, tracking: tracking),
                const SizedBox(height: AppTokens.space12),
                _ItemsCard(order: order),
                const SizedBox(height: AppTokens.space12),
                _DetailsCard(order: order),
                if (order.customerNote.trim().isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space12),
                  _NoteCard(note: order.customerNote),
                ],
              ],
            ),
          ),
        ),
        // Only once the order is over. Reordering something still being
        // cooked is how a customer ends up with two dinners.
        //
        // The whole bar goes on a store whose plugin cannot reorder (task
        // 14.7): an empty footer with its own card colour and safe-area
        // padding would read as something that failed to load.
        if (!order.isActive && ref.watch(capabilitiesProvider).hasReorder)
          Container(
            color: palette.card,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space16,
                  AppTokens.space12,
                  AppTokens.space16,
                  AppTokens.space12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ReorderButton(orderId: order.id, filled: true),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
          child: Icon(Icons.chevron_left, color: palette.ink),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: AppPalette.of(context).card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final totals = order.totals;

    return _Card(
      children: [
        Text('Items', style: text.titleSmall),
        const SizedBox(height: AppTokens.space12),
        for (final item in order.items) ...[
          _ItemRow(item: item),
          const SizedBox(height: AppTokens.space12),
        ],
        Divider(color: palette.line, height: 1),
        const SizedBox(height: AppTokens.space12),
        _TotalRow(label: 'Subtotal', value: totals.totalItems.format()),
        if (totals.hasDiscount)
          _TotalRow(
            label: 'Discount',
            value: '-${totals.totalDiscount.format()}',
          ),
        if (!totals.totalShipping.isZero)
          _TotalRow(
            label: 'Delivery',
            value: totals.totalShipping.format(),
          ),
        if (!totals.totalFees.isZero)
          _TotalRow(label: 'Fees', value: totals.totalFees.format()),
        if (!totals.totalTax.isZero)
          _TotalRow(label: 'Tax', value: totals.totalTax.format()),
        const SizedBox(height: AppTokens.space6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: text.titleMedium),
            Text(totals.totalPrice.format(), style: text.titleMedium),
          ],
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final meta = item.metaSummary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          child: SizedBox.square(
            dimension: 46,
            child: item.image.isEmpty
                ? const DishImagePlaceholder()
                : Image.network(
                    item.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DishImagePlaceholder(),
                  ),
          ),
        ),
        const SizedBox(width: AppTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.quantity}× ${item.name}',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space2),
                Text(
                  meta,
                  style: text.labelSmall?.copyWith(color: palette.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppTokens.space8),
        Text(
          item.total.format(),
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: palette.muted2)),
          Text(value, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    // A pickup order has no delivery address; where it goes is the branch,
    // which is the only thing the order records about the collection point.
    final isPickup = order.type == 'pickup';
    final destination = isPickup ? order.locationName : order.addressLine;

    return _Card(
      children: [
        if (order.paymentMethodTitle.isNotEmpty)
          _DetailRow(label: 'Payment', value: order.paymentMethodTitle),
        // **Only once the order is over.** While it is still coming the
        // estimate belongs in the card at the top, where the design puts it
        // and where task 7.3 draws it; repeating it here said the same thing
        // twice. Afterwards it is no longer a promise but a record of the
        // slot the customer chose, which this list is the right home for.
        if (order.eta.isNotEmpty && !order.isActive)
          _DetailRow(
            label: isPickup ? 'Ready' : 'Estimated',
            value: order.eta,
          ),
        if (destination.isNotEmpty)
          _DetailRow(
            label: order.typeLabel.isEmpty
                ? (isPickup ? 'Pickup' : 'Delivery')
                : order.typeLabel,
            value: destination,
          ),
        if (order.customerPhone.isNotEmpty)
          _DetailRow(label: 'Phone', value: order.customerPhone),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: palette.muted)),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return _Card(
      children: [
        Text('Your note', style: text.titleSmall),
        const SizedBox(height: AppTokens.space6),
        Text(note, style: text.bodySmall?.copyWith(color: palette.muted2)),
      ],
    );
  }
}

class _DetailError extends ConsumerWidget {
  const _DetailError({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    final api = error is ApiException ? error as ApiException : null;

    // A 404 is the plugin's answer for somebody else's order as much as a
    // missing one, and deliberately so. Either way there is nothing to retry.
    final gone = api?.statusCode == 404;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              api?.message ?? 'That order could not be loaded.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: palette.muted2),
            ),
            const SizedBox(height: AppTokens.space12),
            if (!gone)
              TextButton(
                onPressed: () => ref.invalidate(orderProvider(id)),
                child: const Text('Try again'),
              ),
            TextButton(
              onPressed: () => closeOrder(context),
              child: const Text('Back to orders'),
            ),
          ],
        ),
      ),
    );
  }
}

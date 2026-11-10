import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/util/relative_date.dart';
import '../../../core/widgets/dish_image_placeholder.dart';
import '../data/orders_repository.dart';
import '../domain/customer_order.dart';
import 'orders_screen.dart';
import 'widgets/order_status_pill.dart';

/// One order in full — the design's "Order tracking" screen, minus tracking.
///
/// **The timeline and the estimate card are not here.** Both are drawn from a
/// step out of four, which the order payload has no notion of; only the
/// tracking route knows where an order has got to. They are task 7.3, and
/// they are left out rather than faked from the status slug — a store can add
/// statuses of its own, and a guessed step would be confidently wrong.
///
/// **Nor is "Reorder".** An order records its add-ons as display text, not as
/// ids, so a faithful reorder needs the plugin to store a re-submittable
/// selection first. Raised as its own task rather than shipped as a button
/// that quietly drops every choice the customer made.
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
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => _DetailError(error: error, id: orderId),
        AsyncData(:final value) => _Detail(order: value),
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

class _Detail extends StatelessWidget {
  const _Detail({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              AppTokens.space14,
              AppTokens.space16,
              AppTokens.space24,
            ),
            children: [
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
        if (order.eta.isNotEmpty)
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

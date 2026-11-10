import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/relative_date.dart';
import '../../../../core/widgets/dish_image_placeholder.dart';
import '../../domain/order_summary.dart';
import 'order_status_pill.dart';

/// One order in the history list.
///
/// The design's card: number and date over the order type, the status pill,
/// a strip of dish thumbnails with the item count and the total, and — while
/// the order is still happening — its status and estimate underneath.
///
/// **The design's progress bar is not here.** It is drawn from a step index
/// out of four, which only the tracking route knows; this row has a status
/// and nothing to measure it against. It arrives with task 7.3 rather than
/// being faked from the status slug, which would be wrong for any store that
/// adds one of its own.
class OrderRow extends StatelessWidget {
  const OrderRow({
    required this.order,
    required this.onTap,
    super.key,
  });

  /// How many thumbnails fit the row before the count takes over.
  static const _thumbnails = 3;

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.number}',
                          style: text.titleSmall,
                        ),
                        const SizedBox(height: AppTokens.space2),
                        Text(
                          _subtitle(),
                          style: text.bodySmall?.copyWith(color: palette.muted),
                        ),
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
              const SizedBox(height: AppTokens.space12),
              Row(
                children: [
                  for (final item in order.items.take(_thumbnails))
                    Padding(
                      padding: const EdgeInsets.only(right: AppTokens.space6),
                      child: _Thumbnail(item: item),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppTokens.space4),
                      child: Text(
                        _itemCount(),
                        style: text.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ),
                  ),
                  Text(order.total.format(), style: text.titleMedium),
                ],
              ),
              if (order.isActive && order.eta.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space12),
                Divider(color: palette.line, height: 1),
                const SizedBox(height: AppTokens.space10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.statusLabel,
                        style: text.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      // The design's wording, which differs by order type:
                      // a pickup order is ready, a delivery one arrives.
                      '${order.type == 'pickup' ? 'Ready' : 'ETA'} ${order.eta}',
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "Today, 14:02 · Delivery", falling back gracefully when either half is
  /// missing — a store can leave an order with no type at all.
  String _subtitle() {
    final parts = [
      if (order.createdAt != null) relativeDateTime(order.createdAt!),
      if (order.typeLabel.isNotEmpty) order.typeLabel,
    ];

    return parts.join(' · ');
  }

  String _itemCount() => order.itemCount == 1 ? '1 item' : '${order.itemCount} items';
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item});

  final OrderRowItem item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      child: SizedBox.square(
        dimension: 44,
        child: item.image.isEmpty
            ? const DishImagePlaceholder()
            : Image.network(
                item.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const DishImagePlaceholder(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const DishImagePlaceholder(),
              ),
      ),
    );
  }
}

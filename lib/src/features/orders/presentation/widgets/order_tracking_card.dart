import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/customer_order.dart';
import '../../domain/order_tracking.dart';
import 'order_progress_bar.dart';
import 'order_status_pill.dart';

/// The design's estimate card and status timeline, on the order screen.
///
/// Two halves, and only the second needs the tracking route:
///
/// - **The estimate** — "Arriving / ASAP", or "Ready / 6:45 pm" for a pickup
///   — is the order's own `eta` and type. Task 7.2 left it out believing it
///   needed a step index; it never did. Drawn **only while the order is
///   active**, because "Arriving" is a claim about food still coming and a
///   delivered or cancelled order has none.
/// - **The timeline** is the stages, and it is drawn for every order. The
///   store's own words, its own colours, and times already rendered on the
///   restaurant's clock.
class OrderTrackingCard extends StatelessWidget {
  const OrderTrackingCard({
    required this.order,
    required this.tracking,
    super.key,
  });

  final CustomerOrder order;

  /// Null while tracking is loading or after it failed. The estimate still
  /// draws: it comes from the order, so a tracking failure costs the timeline
  /// and the strip, not the whole card.
  final OrderTracking? tracking;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final stages = tracking?.stages ?? const <OrderStage>[];
    final showEstimate = order.isActive && order.eta.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showEstimate) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    _estimateTitle(),
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
                Text(order.eta, style: text.titleMedium),
              ],
            ),
            const SizedBox(height: AppTokens.space10),
          ],
          if (tracking != null && tracking!.stages.isNotEmpty) ...[
            OrderProgressBar(
              fraction: tracking!.progress,
              color: tracking!.current?.color ?? '',
              dimmed: tracking!.isFailed,
            ),
            const SizedBox(height: AppTokens.space10),
            Text(
              tracking!.current?.label ?? tracking!.statusLabel,
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTokens.space16),
            Divider(color: palette.line, height: 1),
            const SizedBox(height: AppTokens.space14),
            for (final (index, stage) in stages.indexed)
              _Stage(
                stage: stage,
                isLast: index == stages.length - 1,
                isCurrent: index == tracking!.step,
              ),
          ] else
            Text(
              _emptyMessage(),
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
        ],
      ),
    );
  }

  /// The design's two words for the same number, which differ by order type:
  /// a pickup order is ready at the counter, a delivery one arrives.
  ///
  /// Not the design's "Arriving in" / "Ready in": the plugin's estimate can be
  /// the literal word "ASAP" as well as a clock time, and "Arriving in ASAP"
  /// does not read. The history row already drops the preposition for the
  /// same reason.
  String _estimateTitle() => order.type == 'pickup' ? 'Ready' : 'Arriving';

  /// Why there is no timeline, in the customer's terms rather than the
  /// store's configuration.
  String _emptyMessage() {
    if (tracking == null) {
      return 'Progress for this order could not be loaded.';
    }

    // The store has the order timeline switched off, or the order predates
    // it, so nothing was ever recorded to show.
    return 'This order has no progress history.';
  }
}

/// One stage: a dot, a connector, the store's label, its note and its time.
///
/// The design gives each of its four steps a fixed subtitle — "The kitchen is
/// cooking". A store's own statuses have no such copy, so the subtitle is the
/// store's note where it allowed one and the time it happened, which is what
/// the website's own tracking page shows.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.stage,
    required this.isLast,
    required this.isCurrent,
  });

  final OrderStage stage;
  final bool isLast;
  final bool isCurrent;

  static const _dot = 20.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final color = parseHexColor(stage.color) ?? palette.brand;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stage.reached ? color : palette.chip,
                border: stage.reached
                    ? null
                    : Border.all(color: palette.line, width: 1.5),
              ),
              child: stage.reached
                  ? Icon(Icons.check, size: 12, color: palette.contrast)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: _connector,
                color: stage.reached ? color : palette.line,
              ),
          ],
        ),
        const SizedBox(width: AppTokens.space12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppTokens.space14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.label,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    // A stage still to come is stated, not promised.
                    color: stage.reached ? palette.ink : palette.muted,
                  ),
                ),
                if (stage.note.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    stage.note,
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
                if (stage.at.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.space2),
                  Text(
                    stage.at,
                    style: text.labelSmall?.copyWith(color: palette.muted2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Enough to clear a label, its note and its time without the dots drifting
  /// apart on a stage that has none of the latter two.
  static const _connector = 34.0;
}

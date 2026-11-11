import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import 'order_status_pill.dart';

/// The design's progress strip: how far through its stages an order is.
///
/// **The fraction comes from the server**, never from the status slug. The
/// design assumes four fixed steps; a store defines its own pipeline on the
/// Order Statuses screen, so the strip is as long as that pipeline and reads
/// as the design's four only when a store happens to have four. See
/// `CONTEXT.md`.
///
/// Takes the stage's own colour so the bar matches the pill above it, and
/// falls back to the brand when the store set none.
class OrderProgressBar extends StatelessWidget {
  const OrderProgressBar({
    required this.fraction,
    this.color = '',
    this.dimmed = false,
    super.key,
  });

  /// How much of the track to fill, 0–1.
  final double fraction;

  /// `#rrggbb` for the filled part. May be empty.
  final String color;

  /// A cancelled or refunded order. The track is drawn empty and muted — the
  /// strip promises food on its way, and there is none coming.
  final bool dimmed;

  static const _height = 6.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fill = dimmed
        ? palette.muted2
        : parseHexColor(color) ?? palette.brand;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: palette.chip)),
            if (!dimmed)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0, 1),
                child: ColoredBox(color: fill),
              ),
          ],
        ),
      ),
    );
  }
}

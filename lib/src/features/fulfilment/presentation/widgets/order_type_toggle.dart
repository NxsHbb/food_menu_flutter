import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/order_types.dart';

/// The design's Delivery / Pickup switch: two pills in a tinted track, the
/// chosen one lifted onto a white card.
///
/// **Only the types the store offers are drawn.** A shop that does not
/// deliver gets a single pill rather than a dead half of a switch, which
/// reads as a label for what it is — the one way this store works.
class OrderTypeToggle extends StatelessWidget {
  const OrderTypeToggle({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// In the server's order. Already filtered to the offered ones.
  final List<OrderTypeOption> options;

  final OrderTypeKind? selected;
  final ValueChanged<OrderTypeKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    if (options.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: _Segment(
                  label: option.label,
                  icon: option.kind == OrderTypeKind.delivery
                      ? Icons.delivery_dining_outlined
                      : Icons.storefront_outlined,
                  selected: option.kind == selected,
                  // A single option is the store's only way of working, so
                  // there is nothing to switch to and the pill is inert.
                  onTap: options.length == 1
                      ? null
                      : () => onSelected(option.kind),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? palette.card : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip + 3),
        elevation: selected ? 1 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusChip + 3),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTokens.space10,
              horizontal: AppTokens.space8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? palette.brand : palette.muted,
                ),
                const SizedBox(width: AppTokens.space8),
                // The store's own label can be long once translated, so it
                // shrinks rather than overflowing a fixed-width segment.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? palette.ink : palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

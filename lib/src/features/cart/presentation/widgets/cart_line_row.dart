import 'package:flutter/material.dart';

import '../../../../core/store_api/models/cart.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/html_text.dart';
import '../../../../core/widgets/dish_image_placeholder.dart';

/// One line of the cart: thumbnail, name, its add-ons, total and a stepper.
class CartLineRow extends StatelessWidget {
  const CartLineRow({
    required this.item,
    required this.busy,
    required this.onQuantity,
    required this.onRemove,
    super.key,
  });

  final CartItem item;

  /// True while this line has a request in flight. The row stays readable and
  /// its controls go quiet, rather than the whole cart showing a spinner.
  final bool busy;

  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final image = item.primaryImage;
    final limits = item.quantityLimits;

    return Opacity(
      opacity: busy ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusControl),
              child: SizedBox(
                width: 64,
                height: 64,
                child: image == null
                    ? const DishImagePlaceholder(label: 'dish')
                    : Image.network(
                        image.thumbnail.isNotEmpty
                            ? image.thumbnail
                            : image.src,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const DishImagePlaceholder(label: 'dish'),
                      ),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          plainText(item.name),
                          style: text.titleSmall,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space8),
                      IconButton(
                        onPressed: busy ? null : onRemove,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: palette.muted,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                  _Choices(item: item),
                  const SizedBox(height: AppTokens.space4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.totals.lineTotal.format(),
                          style: text.titleSmall,
                        ),
                      ),
                      if (limits.editable)
                        _Stepper(
                          quantity: item.quantity,
                          enabled: !busy,
                          // The floor is the line's own minimum, not one: a
                          // dish sold in pairs cannot sit at a single.
                          onChanged: onQuantity,
                          minimum: limits.minimum,
                          step: limits.multipleOf < 1 ? 1 : limits.multipleOf,
                          atMaximum: item.quantity >= limits.maximum,
                        )
                      else
                        Text(
                          '×${item.quantity}',
                          style: text.titleSmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What was chosen on this line.
///
/// Read from the plugin's extension rather than from `item_data`, which is
/// display copy with the quantity baked into the string. A line whose store
/// predates that extension falls back to `item_data`, so an older plugin
/// still shows *something* under the dish name.
class _Choices extends StatelessWidget {
  const _Choices({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    final summary = item.addons.isNotEmpty
        ? item.addons.summary
        : item.itemData
            .map((d) => plainText(d.value))
            .where((v) => v.isNotEmpty)
            .join(' · ');

    if (summary.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.space2),
      child: Text(
        summary,
        style: text.bodySmall?.copyWith(color: palette.muted),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.enabled,
    required this.onChanged,
    required this.minimum,
    required this.step,
    required this.atMaximum,
  });

  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final int minimum;
  final int step;
  final bool atMaximum;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      padding: const EdgeInsets.all(AppTokens.space2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            // Below the minimum there is no smaller line, so the step down
            // removes it — which is also the design's only way out of a row
            // other than the bin.
            onTap: enabled ? () => onChanged(quantity - step) : null,
            semanticLabel: quantity - step < minimum ? 'Remove' : 'One fewer',
          ),
          SizedBox(
            width: 26,
            child: Center(child: Text('$quantity', style: text.labelLarge)),
          ),
          _StepButton(
            icon: Icons.add,
            filled: true,
            onTap: enabled && !atMaximum
                ? () => onChanged(quantity + step)
                : null,
            semanticLabel: 'One more',
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final enabled = onTap != null;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: filled && enabled ? palette.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          ),
          child: Icon(
            icon,
            size: 16,
            color: !enabled
                ? palette.muted
                : filled
                    ? palette.contrast
                    : palette.ink,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/store_api/models/cart.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// Subtotal, and whatever else the server put on the cart — discount, fees,
/// delivery, tax.
///
/// **Which rows exist is a decision, not a layout**: a null shipping total
/// means no rate has been picked rather than free delivery, and a zero fee or
/// tax is nothing to report. Shared by the cart and the checkout summary so
/// the two cannot come to different conclusions about the same cart.
///
/// The amount due is **not** here: the cart puts it under a divider and the
/// checkout puts it in its bottom bar.
class CartTotalsRows extends StatelessWidget {
  const CartTotalsRows({required this.totals, super.key});

  final CartTotals totals;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final shipping = totals.totalShipping;

    return Column(
      children: [
        CartTotalRow(label: 'Subtotal', value: totals.totalItems.format()),
        if (totals.hasDiscount)
          CartTotalRow(
            label: 'Discount',
            value: '−${totals.totalDiscount.format()}',
            emphasis: palette.brand,
          ),
        if (!totals.totalFees.isZero)
          CartTotalRow(label: 'Fees', value: totals.totalFees.format()),
        // Null until a delivery address picks a rate, which for a pickup
        // order never happens — so it is left out rather than shown as free.
        if (shipping != null)
          CartTotalRow(
            label: 'Delivery',
            value: shipping.isZero ? 'Free' : shipping.format(),
          ),
        if (!totals.totalTax.isZero)
          CartTotalRow(label: 'Tax', value: totals.totalTax.format()),
      ],
    );
  }
}

/// One label-and-amount line.
class CartTotalRow extends StatelessWidget {
  const CartTotalRow({
    required this.label,
    required this.value,
    this.emphasis,
    super.key,
  });

  final String label;
  final String value;
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: palette.muted2),
            ),
          ),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasis,
            ),
          ),
        ],
      ),
    );
  }
}

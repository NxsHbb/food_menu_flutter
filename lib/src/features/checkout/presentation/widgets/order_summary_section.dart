import 'package:flutter/material.dart';

import '../../../../core/store_api/models/cart.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../cart/presentation/widgets/cart_totals_rows.dart';
import 'checkout_card.dart';

/// What is being ordered and what it comes to.
///
/// A read-only restatement of the cart — the design offers no steppers here,
/// and the cart screen is one tap back. The money rows are
/// [CartTotalsRows], shared with the cart, so the two cannot disagree about
/// which lines a cart has. The amount due is in the bottom bar, where the
/// design puts it.
class OrderSummarySection extends StatelessWidget {
  const OrderSummarySection({required this.cart, super.key});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutSectionTitle('Order summary'),
          const SizedBox(height: AppTokens.space10),
          for (final item in cart.items) _SummaryLine(item: item),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
            child: Divider(height: 1, color: palette.line),
          ),
          CartTotalsRows(totals: cart.totals),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final addons = item.addons;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${item.quantity}× ',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: item.name),
                    ],
                  ),
                  style: text.bodyMedium?.copyWith(color: palette.muted2),
                ),
                // Two identical dish names with different add-ons are two
                // different orders to the kitchen, so the choices are named
                // rather than left to the price to hint at.
                if (addons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space2),
                    child: Text(
                      addons.summary,
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space10),
          Text(
            item.totals.lineTotal.format(),
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

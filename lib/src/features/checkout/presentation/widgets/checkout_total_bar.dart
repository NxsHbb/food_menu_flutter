import 'package:flutter/material.dart';

import '../../../../core/store_api/models/cart.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// The design's sticky footer: what is due, and the button that places it.
///
/// The amount comes from the cart's own `total_price` — never added up here.
/// Tax, fees and any automatic discount are server-side arithmetic, and a
/// client that recomputed them would disagree with the order it just placed.
class CheckoutTotalBar extends StatelessWidget {
  const CheckoutTotalBar({
    required this.cart,
    required this.label,
    required this.onPlaceOrder,
    this.busy = false,
    super.key,
  });

  final Cart cart;

  /// The button's words, so payment (task 6.3) can name the method.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPlaceOrder;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.line)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space12,
        AppTokens.space16,
        MediaQuery.paddingOf(context).bottom + AppTokens.space12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Total  '),
                      TextSpan(
                        text: 'incl. fees & tax',
                        style: text.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                cart.totals.totalPrice.format(),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          FilledButton(
            onPressed: busy ? null : onPlaceOrder,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label),
          ),
        ],
      ),
    );
  }
}

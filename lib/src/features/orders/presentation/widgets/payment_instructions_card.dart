import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/customer_order.dart';

/// How to pay, for an order whose gateway collected nothing at checkout.
///
/// Bank transfer and cheque are the only two in v1 (task 12.1). The website
/// prints this on its thank-you page and in the order email — neither of
/// which a Store API order fires — so without this card a customer places a
/// bank-transfer order and is never told which account to pay into.
///
/// **The server decides whether there is anything to draw.** It answers null
/// once the order is paid or closed, so this widget never asks "is this
/// gateway offline?" or "is this status still waiting?" — questions the app
/// would answer differently from the store sooner or later.
class PaymentInstructionsCard extends StatelessWidget {
  const PaymentInstructionsCard({required this.instructions, super.key});

  final PaymentInstructions instructions;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        // A hairline in the brand colour: this is the one card on the screen
        // the customer has to act on, and an order already placed otherwise
        // reads as finished.
        border: Border.all(color: palette.brand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 18,
                color: palette.brand,
              ),
              const SizedBox(width: AppTokens.space8),
              // Flexible, not a bare Text: task 14.9's rule, so a long
              // translation ellipsizes instead of striping the row.
              Flexible(
                child: Text(
                  'How to pay',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (instructions.text.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space12),
            Text(
              instructions.text,
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
          for (final detail in instructions.details) ...[
            const SizedBox(height: AppTokens.space12),
            // Label above value rather than beside it. A bank account number
            // or an IBAN is long, and a two-column row of them is the exact
            // shape that overflowed at a large text scale in task 14.9.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.label.isNotEmpty)
                  Text(
                    detail.label,
                    style: text.bodySmall?.copyWith(color: palette.muted2),
                  ),
                Text(
                  detail.value,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

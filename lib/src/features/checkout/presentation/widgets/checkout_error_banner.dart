import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/checkout_failure.dart';

/// A refused order, stated where the customer is looking.
///
/// **Not a snackbar.** A refusal has to be read, acted on and still be there
/// afterwards: a missing postcode is fixed three fields away, and a snackbar
/// is gone before the keyboard has opened. It stays until the next attempt
/// clears it or the customer dismisses it.
class CheckoutErrorBanner extends StatelessWidget {
  const CheckoutErrorBanner({
    required this.failure,
    required this.onDismiss,
    this.onRetry,
    super.key,
  });

  final CheckoutFailure failure;
  final VoidCallback onDismiss;

  /// Offered only when sending the identical order again could work.
  final VoidCallback? onRetry;

  /// What the customer is being asked to do. The server says what went wrong;
  /// this says what to do about it, which the server has no way of knowing.
  String get _advice => switch (failure.kind) {
        CheckoutFailureKind.connection =>
          'Your order was not placed. Nothing has been charged.',
        CheckoutFailureKind.validation =>
          'Check the details below and try again.',
        CheckoutFailureKind.cart =>
          'Your order summary has been updated. Review it and place the '
              'order again.',
        CheckoutFailureKind.slot =>
          'The times below have been refreshed and one is now selected for '
              'you. Check it and place the order again.',
        CheckoutFailureKind.payment => 'Choose another way to pay.',
        CheckoutFailureKind.auth => 'Sign in again to place this order.',
        CheckoutFailureKind.unknown =>
          'Your order was not placed. Nothing has been charged.',
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space14,
        AppTokens.space12,
        AppTokens.space8,
        AppTokens.space12,
      ),
      decoration: BoxDecoration(
        color: palette.warnBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: palette.warnForeground,
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure.message,
                  style: text.bodyMedium?.copyWith(
                    color: palette.warnForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // The server's own per-field complaints, when it listed them
                // — "Street address is required" beats "check your address".
                for (final detail in failure.details)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.space2),
                    child: Text(
                      '• $detail',
                      style: text.bodySmall
                          ?.copyWith(color: palette.warnForeground),
                    ),
                  ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  _advice,
                  style: text.bodySmall
                      ?.copyWith(color: palette.warnForeground),
                ),
                if (onRetry case final retry?) ...[
                  const SizedBox(height: AppTokens.space8),
                  OutlinedButton(
                    onPressed: retry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.warnForeground,
                      side: BorderSide(color: palette.warnForeground),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: palette.warnForeground,
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

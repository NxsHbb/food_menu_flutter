import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/html_text.dart';
import '../../../cart/data/cart_controller.dart';
import '../../data/checkout_controller.dart';
import '../../data/payment_repository.dart';
import '../../domain/payment_method.dart';
import 'checkout_card.dart';

/// The design's payment list: one row per gateway, with a radio.
///
/// Every word in it is the store's. The only thing decided here is which rows
/// can be *chosen* — v1 completes cash on delivery, and the server says which
/// of its gateways this app can finish.
class PaymentSection extends ConsumerWidget {
  const PaymentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);

    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutSectionTitle('Payment method'),
          const SizedBox(height: AppTokens.space12),
          switch (methods) {
            AsyncLoading() => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTokens.space16),
              child: Center(child: CircularProgressIndicator()),
            ),
            AsyncError(:final error) => _Error(
              error: error,
              onRetry: () => ref.invalidate(paymentMethodsProvider),
            ),
            AsyncData(:final value) => _Methods(methods: value),
          },
        ],
      ),
    );
  }
}

class _Methods extends ConsumerWidget {
  const _Methods({required this.methods});

  final PaymentMethods methods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final offered = methods.offered(
      ref.watch(cartControllerProvider).value?.paymentMethods,
    );

    if (offered.isEmpty) {
      return _Notice(
        // A store with no gateway enabled cannot be ordered from at all — the
        // Store API refuses every order — so this is the whole truth rather
        // than an app limitation.
        message: 'This store is not accepting payment right now.',
      );
    }

    final selected = ref.watch(selectedPaymentMethodProvider);
    final usable = offered.where((method) => method.supported).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final method in offered) ...[
          _MethodRow(
            method: method,
            selected: method.id == selected?.id,
            onTap: method.supported
                ? () => ref
                      .read(checkoutControllerProvider.notifier)
                      .choosePayment(method.id)
                : null,
          ),
          const SizedBox(height: AppTokens.space8),
        ],
        // Only when it explains something: a store whose only gateways are
        // card or PayPal would otherwise show a list nothing can be picked
        // from and no reason why.
        if (usable.isEmpty)
          _Notice(
            message: 'Paying this way is not in the app yet. '
                'Card and PayPal are coming.',
          )
        else if (usable.length < offered.length)
          Text(
            'Other methods are coming to the app soon.',
            style: text.bodySmall?.copyWith(color: palette.muted),
          ),
      ],
    );
  }
}

/// One gateway, in the design's row: a tile, two lines and a radio.
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;

  /// Null for a gateway this app cannot complete, which draws it dimmed and
  /// unselectable rather than hiding it.
  final VoidCallback? onTap;

  /// The design puts a short code in the tile. A gateway id does not
  /// abbreviate into one — "stripe" would read "STRI" — so a known id gets
  /// its own mark and anything else gets a wallet.
  IconData get _icon => switch (method.id) {
        'cod' => Icons.payments_outlined,
        'bacs' => Icons.account_balance_outlined,
        'cheque' => Icons.receipt_long_outlined,
        'paypal' || 'ppcp-gateway' => Icons.account_balance_wallet_outlined,
        _ when method.id.contains('stripe') => Icons.credit_card,
        _ => Icons.account_balance_wallet_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final title = plainText(method.title);
    final description = plainText(method.description);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: selected ? palette.tint : palette.field,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space14,
              vertical: AppTokens.space12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
              border: Border.all(
                color: selected ? palette.brand : palette.line,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.chip,
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  ),
                  child: Icon(_icon, size: 16, color: palette.muted2),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              text.bodySmall?.copyWith(color: palette.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? palette.brand : palette.ring,
          width: 1.8,
        ),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: palette.brand,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: palette.warnBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      child: Text(
        message,
        style: text.bodySmall?.copyWith(color: palette.warnForeground),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          api?.message ?? 'Could not load the payment methods.',
          style: text.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: AppTokens.space10),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

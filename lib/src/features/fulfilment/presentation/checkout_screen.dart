import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/presentation/cart_screen.dart';
import 'widgets/fulfilment_section.dart';

/// The design's checkout.
///
/// Outside the tab shell, with its own back button, because the design shows
/// no tab bar here.
///
/// **Task 5.4 built the fulfilment half of it**: how the order arrives and
/// when. Contact details, the address block, payment and the order summary
/// are task 6.1, and the page is laid out so they drop in as further sections
/// rather than needing it rebuilt.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  static const routePath = '/checkout';
  static const routeName = 'checkout';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final cart = ref.watch(cartControllerProvider).value;

    return Scaffold(
      backgroundColor: palette.page,
      body: Column(
        children: [
          _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space16,
                AppTokens.space24,
              ),
              children: [
                // Reached with an empty cart only by a deep link or by
                // clearing the cart in another tab, but it has to say
                // something rather than offer times for nothing.
                if (cart != null && cart.isEmpty)
                  _Card(
                    child: Text(
                      'Your cart is empty.',
                      style: text.bodyMedium?.copyWith(color: palette.muted),
                    ),
                  )
                else
                  const _Card(child: FulfilmentSection()),
                const SizedBox(height: AppTokens.space16),
                _Card(
                  child: Row(
                    children: [
                      Icon(
                        Icons.construction_outlined,
                        size: 18,
                        color: palette.muted,
                      ),
                      const SizedBox(width: AppTokens.space10),
                      Expanded(
                        child: Text(
                          'Contact details, address, payment and the order '
                          'summary arrive in Phase 6.',
                          style: text.bodySmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space10,
            AppTokens.space16,
            AppTokens.space12,
          ),
          child: Row(
            children: [
              _BackButton(),
              const SizedBox(width: AppTokens.space12),
              Text(
                'Checkout',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        side: BorderSide(color: palette.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        // The cart, not `pop`, when there is nothing to pop: this route sits
        // outside the shell, so a deep link lands here with an empty stack
        // and a dead button.
        onTap: () => context.canPop()
            ? context.pop()
            : context.goNamed(CartScreen.routeName),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back, size: 20),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        border: Border.all(color: palette.line),
      ),
      child: child,
    );
  }
}

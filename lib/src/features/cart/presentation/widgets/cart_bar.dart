import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../data/cart_controller.dart';
import '../cart_screen.dart';

/// The design's floating cart bar: a count, "View cart", and the subtotal.
///
/// Shown over the menu screens whenever there is something in the cart, which
/// is the design's rule — a customer three screens into a menu should not
/// have to go looking for what they have already chosen.
///
/// Absent on the cart screen itself, which is the thing it leads to, and
/// absent on a dish, which has its own bottom bar.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  /// How much room a screen must leave below its own content so the bar never
  /// covers the last row of a list.
  static const height = 56.0;
  static const reservedSpace = height + AppTokens.space16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider).value;
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    // Nothing while the first read is in flight, and nothing for an empty
    // cart: a bar that says zero is just a bar in the way.
    if (cart == null || cart.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        0,
        AppTokens.space16,
        AppTokens.space12,
      ),
      child: Material(
        color: palette.ink,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        elevation: 6,
        shadowColor: palette.ink.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
          onTap: () => context.goNamed(CartScreen.routeName),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space8,
                AppTokens.space8,
                AppTokens.space8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.brand,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusChip),
                    ),
                    child: Text(
                      '${cart.itemsCount}',
                      style: text.labelLarge?.copyWith(
                        color: palette.contrast,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: Text(
                      'View cart',
                      style: text.titleSmall?.copyWith(color: palette.card),
                    ),
                  ),
                  Container(
                    height: 40,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space14,
                    ),
                    decoration: BoxDecoration(
                      color: palette.brand,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusControl),
                    ),
                    child: Text(
                      // The subtotal, as the design has it: the amount due
                      // depends on delivery and tax that the cart screen and
                      // checkout settle.
                      cart.totals.totalItems.format(),
                      style: text.titleSmall?.copyWith(
                        color: palette.contrast,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Room a scrolling menu screen must leave at the bottom so the floating bar
/// never sits on top of the last dish.
///
/// Zero when there is no bar, so nothing is reserved for a bar that is not
/// there.
final cartBarInsetProvider = Provider<double>((ref) {
  return ref.watch(cartCountProvider) > 0 ? CartBar.reservedSpace : 0;
});

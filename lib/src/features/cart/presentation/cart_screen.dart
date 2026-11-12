import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/cart.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../checkout/presentation/widgets/tip_section.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../../menu/presentation/menu_list_screen.dart';
import '../data/cart_controller.dart';
import 'widgets/cart_line_row.dart';
import 'widgets/cart_totals_rows.dart';

/// The design's cart: the lines, what they cost, and the way to checkout.
///
/// Two things the design draws are **not** here, and both are v2 rather than
/// unfinished — see `PLAN.md`:
///
/// - the **coupon field** and its discount line, and
/// - the **"Complete your meal"** carousel, which is the Order Bumps feature.
///
/// The discount row still appears when the server applies one of its own, as
/// the plugin's automatic discount does, because that arrives in the cart
/// totals whether or not the app ever asks for it.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const routePath = '/cart';
  static const routeName = 'cart';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (cart) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError(:final error) => _CartError(error: error),
          AsyncData(:final value) =>
            value.isEmpty ? const _EmptyCart() : _Cart(cart: value),
        },
      ),
    );
  }
}

class _Cart extends ConsumerWidget {
  const _Cart({required this.cart});

  final Cart cart;

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final controller = ref.read(cartControllerProvider.notifier);

    return Column(
      children: [
        _Header(cart: cart),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space16,
                AppTokens.space14,
                AppTokens.space16,
                AppTokens.space20,
              ),
              children: [
                // Anything the server is unhappy about — a dish that went out
                // of stock while the cart sat there — before the lines, since
                // it explains what the customer is about to see change.
                for (final message in cart.errors) ...[
                  _Notice(message: message),
                  const SizedBox(height: AppTokens.space12),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusCardLarge),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space14,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < cart.items.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: palette.line),
                        CartLineRow(
                          item: cart.items[i],
                          busy: controller.isPending(cart.items[i].key),
                          onQuantity: (quantity) => _change(
                            context,
                            ref,
                            () => controller.setQuantity(
                              cart.items[i],
                              quantity,
                            ),
                          ),
                          onRemove: () => _change(
                            context,
                            ref,
                            () => controller.remove(cart.items[i]),
                          ),
                        ),
                      ],
                      Divider(height: 1, color: palette.line),
                      _AddMore(),
                    ],
                  ),
                ),
                // A store can ask for the tip on the cart, on the checkout or
                // on both (task 9.4). Honoured in both places, or a store set
                // to "cart" would find the app asking nowhere.
                const SizedBox(height: AppTokens.space12),
                const TipSection(screen: 'cart'),
                const SizedBox(height: AppTokens.space12),
                _Totals(totals: cart.totals),
              ],
            ),
          ),
        ),
        _CheckoutBar(cart: cart),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final count = cart.itemsCount;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space20,
        AppTokens.space12,
        AppTokens.space12,
        AppTokens.space14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My cart', style: text.headlineSmall),
                const SizedBox(height: AppTokens.space2),
                Text(
                  count == 1 ? '1 item' : '$count items',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          if (!cart.isEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }

  /// Asked first, because emptying a cart cannot be undone and the button
  /// sits a thumb's width from the quantity steppers.
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty your cart?'),
        content: const Text('This removes everything in it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(cartControllerProvider.notifier).clear();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _AddMore extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.goNamed(MenuListScreen.routeName),
        icon: Icon(Icons.add, size: 18, color: palette.brand),
        label: const Text('Add more items'),
      ),
    );
  }
}

/// Subtotal, anything the server added or took off, and the amount due.
class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final CartTotals totals;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
      ),
      padding: const EdgeInsets.all(AppTokens.space14),
      child: Column(
        children: [
          CartTotalsRows(totals: totals),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
            child: Divider(height: 1, color: palette.line),
          ),
          Row(
            children: [
              Expanded(child: Text('Total', style: text.titleMedium)),
              Text(
                totals.totalPrice.format(),
                style: text.titleLarge?.copyWith(color: palette.brand),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space12,
        AppTokens.space16,
        MediaQuery.paddingOf(context).bottom + AppTokens.space12,
      ),
      child: FilledButton(
        onPressed: () => context.pushNamed(CheckoutScreen.routeName),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Go to checkout'),
            const SizedBox(width: AppTokens.space8),
            Text(
              cart.totals.totalPrice.format(),
              style: text.labelLarge?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: palette.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 40,
                color: palette.brand,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text('Your cart is empty', style: text.titleLarge),
            const SizedBox(height: AppTokens.space8),
            Text(
              'Add something delicious from the menu.',
              style: text.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space20),
            FilledButton(
              onPressed: () => context.goNamed(MenuListScreen.routeName),
              child: const Text('Browse menu'),
            ),
          ],
        ),
      ),
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
      decoration: BoxDecoration(
        color: palette.warnBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      padding: const EdgeInsets.all(AppTokens.space12),
      child: Text(
        message,
        style: text.bodySmall?.copyWith(color: palette.warnForeground),
      ),
    );
  }
}

class _CartError extends ConsumerWidget {
  const _CartError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final api = error is ApiException ? error as ApiException : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text(
              api?.message ?? 'Could not load your cart.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space16),
            OutlinedButton(
              onPressed: ref.read(cartControllerProvider.notifier).reload,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

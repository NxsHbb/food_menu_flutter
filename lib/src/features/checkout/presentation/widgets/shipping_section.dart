import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/store_api/models/cart.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../cart/data/cart_controller.dart';
import '../../../fulfilment/data/fulfilment_controller.dart';
import '../../../fulfilment/domain/order_types.dart';
import 'checkout_card.dart';

/// How the order gets there, and what that costs (task 8.5).
///
/// A store running one shipping method charges it whether or not anything is
/// drawn — which is what the app did before: it rendered `total_shipping`
/// once the server had decided for it. A store running zones, or two methods,
/// was giving a choice the customer never saw, and a cart with no rate
/// selected can refuse checkout outright.
///
/// **Draws nothing it cannot act on.** No rates means a pickup order, a store
/// with no zone, or an address no zone covers; the last is a real refusal and
/// it belongs to the address block, not here.
class ShippingSection extends ConsumerWidget {
  const ShippingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pickup collects nothing: a "Delivery method" on an order the customer
    // is collecting is a question about something that will not happen.
    if (ref.watch(resolvedOrderTypeProvider) != OrderTypeKind.delivery) {
      return const SizedBox.shrink();
    }

    final cart = ref.watch(cartControllerProvider).value;

    if (cart == null || !cart.needsShipping) return const SizedBox.shrink();

    final packages = [
      for (final package in cart.shippingPackages)
        if (package.rates.isNotEmpty) package,
    ];

    if (packages.isEmpty) return const SizedBox.shrink();

    return CheckoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutSectionTitle('Delivery method'),
          const SizedBox(height: AppTokens.space12),
          for (final package in packages) ...[
            // Named only when there is more than one, which a restaurant
            // order never is — but WooCommerce can split a cart and the
            // rows would otherwise read as one list of alternatives.
            if (packages.length > 1 && package.name.isNotEmpty) ...[
              Text(
                package.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.of(context).muted,
                ),
              ),
              const SizedBox(height: AppTokens.space8),
            ],
            _Rates(package: package),
          ],
        ],
      ),
    );
  }
}

class _Rates extends ConsumerWidget {
  const _Rates({required this.package});

  final ShippingPackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(cartControllerProvider.notifier);
    final rates = package.rates;

    // **One rate is not a choice.** The store charges it either way, so it is
    // reported rather than offered — a radio that cannot change reads as a
    // control that is broken.
    if (rates.length == 1) return _RateRow(rate: rates.single);

    return Column(
      children: [
        for (final rate in rates) ...[
          _RateRow(
            rate: rate,
            // Every row in a list of alternatives carries a radio, including
            // the one already chosen — a device showed the selected row as
            // the only one without, which reads as the odd one out.
            chooseable: true,
            onTap: rate.selected
                ? null
                : () => controller.selectShippingRate(
                    packageId: package.packageId,
                    rateId: rate.rateId,
                  ),
            busy: controller.isPending('shipping:${rate.rateId}'),
          ),
          if (rate != rates.last) const SizedBox(height: AppTokens.space8),
        ],
      ],
    );
  }
}

/// One way to deliver, at its own price.
class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.rate,
    this.chooseable = false,
    this.onTap,
    this.busy = false,
  });

  final ShippingRate rate;

  /// Whether this row is one of several. A lone rate is reported rather than
  /// offered, and draws no radio at all.
  final bool chooseable;

  /// Null for the rate already in force, and for the lone rate of a store
  /// that offers one.
  final VoidCallback? onTap;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final selected = rate.selected;

    // The store's own words for the method, and for the time where it makes
    // a promise about one. Neither is composed here.
    final note = [
      if (rate.description.isNotEmpty) rate.description,
      if (rate.deliveryTime.isNotEmpty) rate.deliveryTime,
    ].join(' · ');

    return Semantics(
      // Announced as what it is: one of several ways to be delivered, with
      // the chosen one marked. The visual radio says the same thing.
      inMutuallyExclusiveGroup: chooseable,
      selected: chooseable ? selected : null,
      button: chooseable,
      child: Material(
        color: selected ? palette.tint : palette.field,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        child: InkWell(
          onTap: busy ? null : onTap,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rate.name,
                        maxLines: 2,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (note.isNotEmpty)
                        Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: palette.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  // "Free" rather than "$0.00", which reads as a price that
                  // failed to load.
                  rate.isFree ? 'Free' : rate.price.format(),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (chooseable) ...[
                  const SizedBox(width: AppTokens.space8),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(2),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _Radio(selected: selected),
                  ),
                ],
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? palette.brand : palette.line,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.brand,
                ),
              ),
            )
          : null,
    );
  }
}

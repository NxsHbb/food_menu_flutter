import 'package:flutter/material.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/html_text.dart';
import '../../../../core/widgets/dish_image_placeholder.dart';
import '../../../cart/presentation/widgets/quick_add_button.dart';
import '../../../wishlist/presentation/widgets/wishlist_heart.dart';

/// The design's menu list row: square image, name, description, price, add.
///
/// A row rather than a card, because the menu screen is a scannable list
/// while the landing screen is a browsable grid.
///
/// **The heart here is not in the design**, which draws it on the grid card
/// and the detail screen only. It is added because `PLAN.md` asks for it on
/// cards and rows, and because being able to save a dish from the grid but
/// not from the list of the same dishes is a gap a customer would notice. It
/// borrows the design's own unfilled-heart tone rather than inventing one.
class DishRow extends StatelessWidget {
  const DishRow({
    required this.product,
    required this.onTap,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final image = product.primaryImage;
    final prices = product.prices;
    final description = plainText(product.shortDescription);

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: image == null
                      ? const DishImagePlaceholder(stripeWidth: 5)
                      : Image.network(
                          image.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const DishImagePlaceholder(stripeWidth: 5),
                        ),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                        ),
                        // Beside the name rather than over the photo: the
                        // row's image is 76px, which a 30px disc would
                        // dominate, and the bottom corner already holds the
                        // add button. See the class docblock.
                        WishlistHeart(
                          product: product,
                          style: HeartStyle.bare,
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: AppTokens.space6,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              Text(
                                (prices.hasRange
                                        ? prices.priceRangeMin!
                                        : prices.price)
                                    .format(),
                                style: text.titleSmall
                                    ?.copyWith(color: palette.brand),
                              ),
                              // The design's optLabel: tells the customer a
                              // tap leads to choices rather than the cart.
                              // Required add-on groups count, not just
                              // variations — see `Product.needsChoices`.
                              if (product.needsChoices)
                                Text(
                                  'options',
                                  style: text.labelSmall
                                      ?.copyWith(color: palette.muted),
                                )
                              else if (prices.isDiscounted)
                                Text(
                                  prices.regularPrice.format(),
                                  style: text.bodySmall?.copyWith(
                                    color: palette.muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        QuickAddButton(
                          product: product,
                          size: 32,
                          borderRadius: AppTokens.radiusChip,
                          iconSize: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

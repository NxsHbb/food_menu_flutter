import 'package:flutter/material.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/dish_image_placeholder.dart';
import '../../../cart/presentation/widgets/quick_add_button.dart';
import '../../../wishlist/presentation/widgets/wishlist_heart.dart';

/// The design's dish card: image, name, rating row, price and an add button,
/// with the favourite heart over the top-right of the photo.
///
/// One thing the design shows is **not rendered**: the per-dish prep time, for
/// which no Store API field exists. It is left out rather than faked, so the
/// card never shows a number the backend cannot stand behind.
class DishCard extends StatelessWidget {
  const DishCard({
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

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expanded, not a fixed aspect ratio: the text block below sizes
            // to its content, which changes with the platform text scale, and
            // the image takes whatever height is left. A fixed ratio here
            // overflowed the card by 11px at the default scale.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // **Dimmed when the dish cannot be ordered.** The design has
                  // no unavailable card, and dimming the photo alone reads as
                  // inactive at a glance while the name, price and the store's
                  // reason underneath stay at full contrast.
                  Opacity(
                    opacity: product.isOrderable ? 1 : 0.4,
                    child: image == null
                        ? const DishImagePlaceholder()
                        : Image.network(
                            image.src,
                            fit: BoxFit.cover,
                            // A dish whose photo fails to load still has to
                            // look deliberate, so fall back to the same
                            // placeholder.
                            errorBuilder: (_, _, _) =>
                                const DishImagePlaceholder(),
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const DishImagePlaceholder(),
                          ),
                  ),
                  Positioned(
                    top: AppTokens.space8,
                    right: AppTokens.space8,
                    child: WishlistHeart(product: product),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: AppTokens.space4),
                  _RatingRow(product: product),
                  const SizedBox(height: AppTokens.space10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (prices.hasRange)
                              Text(
                                'from',
                                style: text.labelSmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            // Wrap, not Row: a discounted dish shows two
                            // prices, which overflow a narrow card side by
                            // side. This lets the struck price drop below.
                            Wrap(
                              spacing: AppTokens.space6,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                Text(
                                  (prices.hasRange
                                          ? prices.priceRangeMin!
                                          : prices.price)
                                      .format(),
                                  style: text.titleMedium
                                      ?.copyWith(color: palette.brand),
                                ),
                                if (prices.isDiscounted)
                                  Text(
                                    prices.regularPrice.format(),
                                    style: text.bodySmall?.copyWith(
                                      color: palette.muted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      QuickAddButton(
                        product: product,
                        size: 34,
                        borderRadius: AppTokens.radiusControl,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Star, rating and review count. Hidden entirely when nothing has been
/// reviewed, because "★ 0 (0)" reads as a bad score rather than no score.
class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    // **What is wrong with the dish beats what nobody has said about it.**
    // A dish outside its hours says so here in the store's own words, which
    // is the only place a card has room for them.
    final reason = product.unavailableReason;

    if (reason.isNotEmpty) {
      return Text(
        reason,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: palette.muted),
      );
    }

    if (product.reviewCount == 0) {
      return Text(
        'No reviews yet',
        style: text.bodySmall?.copyWith(color: palette.muted),
      );
    }

    return Row(
      children: [
        Icon(Icons.star_rounded, size: 14, color: palette.star),
        const SizedBox(width: AppTokens.space2),
        Text(
          product.averageRating.toStringAsFixed(1),
          style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: AppTokens.space4),
        Text(
          '(${product.reviewCount})',
          style: text.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

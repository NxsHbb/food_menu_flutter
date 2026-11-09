import 'package:flutter/material.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/dish_image_placeholder.dart';
import 'wishlist_heart.dart';

/// The wishlist screen's row: image, name, price and a filled heart.
///
/// Deliberately not [DishRow]. The design draws a more compact row here — no
/// description, no rating, no add button — because this list is a set of
/// decisions already made, not a menu to be browsed. Reusing the menu row
/// would have put an add button next to a heart in a 10px-padded card.
class WishlistRow extends StatelessWidget {
  const WishlistRow({
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
      borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                child: SizedBox(
                  width: 72,
                  height: 72,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.space4),
                    Text(
                      // A saved variable dish shows its lowest price, the same
                      // as it does everywhere else in the app.
                      (prices.hasRange ? prices.priceRangeMin! : prices.price)
                          .format(),
                      style: text.titleMedium?.copyWith(color: palette.brand),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              // Tinted and filled: on this screen the heart's job is to take
              // the dish off the list, so it is always in the saved state.
              WishlistHeart(product: product, style: HeartStyle.tinted),
            ],
          ),
        ),
      ),
    );
  }
}

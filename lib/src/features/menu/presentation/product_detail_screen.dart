import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/product.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/util/html_text.dart';
import '../../../core/widgets/dish_image_placeholder.dart';
import 'widgets/food_data_section.dart';
import 'widgets/food_tags.dart';
import '../data/menu_repository.dart';

/// The design's dish detail screen: hero image, details, quantity and add.
///
/// Three things the design shows are **not** built here, each belonging to a
/// later task rather than being absent for want of data:
///
/// - **add-on groups** — task 4.4, once the plugin exposes them;
/// - **special instructions** — a cart line note, task 4.5;
/// - **the favourite heart** — task 3.6, once wishlist endpoints exist.
///
/// Food tags come from WooCommerce's `product_tag`. Ingredients and nutrition
/// come from the plugin's `food-menu-pro` Store API extension, added in
/// food-menu-pro#5 — before that they were unreachable for products. Both are
/// absent on a site running an older plugin, and the sections simply do not
/// appear.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({required this.productId, super.key});

  static const routePath = '/dish/:id';
  static const routeName = 'dish';

  final int productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));

    return Scaffold(
      body: switch (product) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => _DetailError(error: error),
        AsyncData(:final value) => _Detail(
            product: value,
            quantity: _quantity,
            onQuantityChanged: (q) => setState(() => _quantity = q),
          ),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(product: product)),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTokens.radiusSheet),
                    ),
                  ),
                  transform: Matrix4.translationValues(0, -16, 0),
                  padding: const EdgeInsets.all(AppTokens.space20),
                  child: _Body(product: product),
                ),
              ),
            ],
          ),
        ),
        _AddBar(
          product: product,
          quantity: quantity,
          onQuantityChanged: onQuantityChanged,
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final image = product.primaryImage;
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image == null)
            const DishImagePlaceholder(label: 'product image')
          else
            Image.network(
              image.src,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const DishImagePlaceholder(label: 'product image'),
            ),
          // Scrim so the close button stays legible over a bright photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x55000000), Color(0x00000000)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            top: top + AppTokens.space8,
            left: AppTokens.space16,
            child: const _CircleButton(icon: Icons.close),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.card,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.pop(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 20, color: palette.ink),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final prices = product.prices;
    final description = plainText(product.description);
    final lowStock = product.lowStockWarning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: text.headlineSmall),
        const SizedBox(height: AppTokens.space8),
        if (product.reviewCount > 0)
          Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: palette.star),
              const SizedBox(width: AppTokens.space4),
              Text(
                product.averageRating.toStringAsFixed(1),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppTokens.space4),
              Text(
                '(${product.reviewCount} reviews)',
                style: text.bodyMedium?.copyWith(color: palette.muted),
              ),
            ],
          )
        else
          Text(
            'No reviews yet',
            style: text.bodyMedium?.copyWith(color: palette.muted),
          ),
        const SizedBox(height: AppTokens.space12),
        Wrap(
          spacing: AppTokens.space8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            if (prices.hasRange)
              Text(
                'from',
                style: text.bodyMedium?.copyWith(color: palette.muted),
              ),
            Text(
              (prices.hasRange ? prices.priceRangeMin! : prices.price).format(),
              style: text.headlineMedium?.copyWith(color: palette.brand),
            ),
            if (prices.hasRange)
              Text(
                'to ${prices.priceRangeMax!.format()}',
                style: text.bodyMedium?.copyWith(color: palette.muted),
              )
            else if (prices.isDiscounted)
              Text(
                prices.regularPrice.format(),
                style: text.bodyLarge?.copyWith(
                  color: palette.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        if (!product.isOrderable || lowStock != null) ...[
          const SizedBox(height: AppTokens.space12),
          _StockBadge(product: product, lowStock: lowStock),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space16),
          Text(
            description,
            style: text.bodyLarge?.copyWith(color: palette.muted2),
          ),
        ],
        if (product.tags.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space16),
          FoodTags(tags: product.tags),
        ],
        if (product.ingredients.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space24),
          FoodDataSection(
            title: 'Ingredients',
            rows: product.ingredients,
          ),
        ],
        if (product.nutrition.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space24),
          FoodDataSection(
            title: 'Nutrition facts',
            rows: product.nutrition,
          ),
        ],
      ],
    );
  }

}

/// Out-of-stock or low-stock notice, preferring the site's own wording.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product, required this.lowStock});

  final Product product;
  final int? lowStock;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final isOut = !product.isOrderable;

    final label = isOut
        ? (product.stockText.isNotEmpty ? product.stockText : 'Out of stock')
        : 'Only $lowStock left';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space10,
        vertical: AppTokens.space6,
      ),
      decoration: BoxDecoration(
        color: isOut ? palette.tint : palette.warnBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Text(
        label,
        style: text.labelMedium?.copyWith(
          color: isOut ? palette.brand : palette.warnForeground,
        ),
      ),
    );
  }
}

/// Sticky bottom bar: quantity stepper and the add button with a line total.
class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final orderable = product.isOrderable;
    final prices = product.prices;
    // A variable dish has no single price until a variation is chosen, so the
    // bar shows no total rather than a misleading one.
    final showTotal = !prices.hasRange;
    final lineTotal = prices.price * quantity;

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
      child: Row(
        children: [
          _Stepper(
            quantity: quantity,
            enabled: orderable,
            onChanged: onQuantityChanged,
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: FilledButton(
              onPressed: orderable
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Add to cart arrives in Phase 4.'),
                        ),
                      )
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    orderable
                        ? (prices.hasRange ? 'Choose options' : 'Add to cart')
                        : 'Unavailable',
                  ),
                  if (orderable && showTotal) ...[
                    const SizedBox(width: AppTokens.space8),
                    Text(
                      lineTotal.format(),
                      style: text.labelLarge?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            // One is the floor; removing the line is the cart's job.
            onTap: enabled && quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 32,
            child: Center(
              child: Text('$quantity', style: text.titleSmall),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: enabled ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? palette.muted : palette.ink,
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    // A deleted or hidden dish 404s, which deserves its own wording rather
    // than a generic network message.
    final api = error is ApiException ? error as ApiException : null;
    final message = api?.statusCode == 404
        ? 'This dish is no longer on the menu.'
        : api?.message ?? 'Could not load this dish.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_meals_outlined, size: 40, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppTokens.space16),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Back to the menu'),
            ),
          ],
        ),
      ),
    );
  }
}

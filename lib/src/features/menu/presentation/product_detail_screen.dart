import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/store_api/models/money.dart';
import '../../../core/store_api/models/product.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/util/html_text.dart';
import '../../../core/widgets/dish_image_placeholder.dart';
import '../../wishlist/presentation/widgets/wishlist_heart.dart';
import 'widgets/addon_group_card.dart';
import 'widgets/food_data_section.dart';
import 'widgets/food_tags.dart';
import '../data/addons_repository.dart';
import '../data/menu_repository.dart';
import '../domain/addon_selection.dart';
import '../domain/product_addons.dart';

/// The design's dish detail screen: hero image, details, add-ons, quantity
/// and add.
///
/// One thing the design shows is **not** built here: **special
/// instructions**, which is a note on the cart line rather than a priced
/// add-on, and belongs to task 4.5 with the rest of the cart.
///
/// Food tags come from WooCommerce's `product_tag`. Ingredients and nutrition
/// come from the plugin's `food-menu-pro` Store API extension, added in
/// food-menu-pro#5 — before that they were unreachable for products. Both are
/// absent on a site running an older plugin, and the sections simply do not
/// appear. Add-on groups behave the same way: they come from the plugin's own
/// namespace, and a store without that route shows a dish with no choices
/// rather than an error.
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
  AddonSelection _selection = const AddonSelection();

  /// Whether the customer has pressed Add while a required group was still
  /// unanswered. Until they do, an untouched required group is not an error —
  /// it is simply a question not yet reached.
  bool _tried = false;

  /// The dish whose defaults [_selection] was seeded from, so a dish opened
  /// after this one gets its own.
  int? _seededFor;

  void _seed(ProductAddons addons) {
    if (_seededFor == addons.productId) return;
    _seededFor = addons.productId;
    _selection = AddonSelection.fromDefaults(addons.groups);
    _tried = false;
  }

  void _update(AddonSelection next) {
    setState(() {
      _selection = next;
      // Answering the last open group should clear the red cards as it goes,
      // rather than leaving them until the next press.
      if (_tried && _selection.isSatisfied(_groups)) _tried = false;
    });
  }

  /// The dish's groups as currently loaded, for the callbacks that need them
  /// outside a build.
  List<AddonGroup> get _groups =>
      ref.read(productAddonsProvider(widget.productId)).value?.groups ??
      const [];

  void _onAdd(BuildContext context) {
    final unanswered = _selection.unanswered(_groups);

    if (unanswered.isNotEmpty) {
      setState(() => _tried = true);
      // The group needing an answer may be well off-screen, so it is named
      // rather than only highlighted.
      _say(context, 'Choose ${unanswered.first.title.toLowerCase()} first.');
      return;
    }

    _say(context, 'Add to cart arrives in task 4.5.');
  }

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));

    // Never an error state by design: a store without the add-ons route
    // resolves to no groups. See `addonsRepositoryProvider`.
    final addons = ref.watch(productAddonsProvider(widget.productId)).value;

    // Seeded here rather than from a listener: the provider is cached per
    // dish, so coming back to one already loaded would never fire a change.
    if (addons != null) _seed(addons);

    final groups = addons?.groups ?? const <AddonGroup>[];

    return Scaffold(
      body: switch (product) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => _DetailError(error: error),
        AsyncData(:final value) => _Detail(
            product: value,
            groups: groups,
            selection: _selection,
            showErrors: _tried,
            quantity: _quantity,
            onQuantityChanged: (q) => setState(() => _quantity = q),
            onToggle: (group, option) =>
                _update(_selection.toggle(group, option)),
            onQuantity: (group, option, qty) =>
                _update(_selection.setQuantity(group, option, qty)),
            onText: (group, text) => _update(_selection.setText(group, text)),
            onLimitReached: (group) => _say(
              context,
              'Select up to ${group.choiceLimit} ${group.title.toLowerCase()}.',
            ),
            onAdd: () => _onAdd(context),
          ),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.product,
    required this.groups,
    required this.selection,
    required this.showErrors,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onToggle,
    required this.onQuantity,
    required this.onText,
    required this.onLimitReached,
    required this.onAdd,
  });

  final Product product;
  final List<AddonGroup> groups;
  final AddonSelection selection;
  final bool showErrors;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final void Function(AddonGroup group, AddonOption option) onToggle;
  final void Function(AddonGroup group, AddonOption option, int qty) onQuantity;
  final void Function(AddonGroup group, String text) onText;
  final void Function(AddonGroup group) onLimitReached;
  final VoidCallback onAdd;

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
                  child: _Body(
                    product: product,
                    groups: groups,
                    selection: selection,
                    showErrors: showErrors,
                    onToggle: onToggle,
                    onQuantity: onQuantity,
                    onText: onText,
                    onLimitReached: onLimitReached,
                  ),
                ),
              ),
            ],
          ),
        ),
        _AddBar(
          product: product,
          groups: groups,
          selection: selection,
          quantity: quantity,
          onQuantityChanged: onQuantityChanged,
          onAdd: onAdd,
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
          // The design pairs the close button with the heart across the top of
          // the photo, so they share one row.
          Positioned(
            top: top + AppTokens.space8,
            left: AppTokens.space16,
            right: AppTokens.space16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _CircleButton(icon: Icons.close),
                WishlistHeart(product: product, size: 38),
              ],
            ),
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
  const _Body({
    required this.product,
    required this.groups,
    required this.selection,
    required this.showErrors,
    required this.onToggle,
    required this.onQuantity,
    required this.onText,
    required this.onLimitReached,
  });

  final Product product;
  final List<AddonGroup> groups;
  final AddonSelection selection;
  final bool showErrors;
  final void Function(AddonGroup group, AddonOption option) onToggle;
  final void Function(AddonGroup group, AddonOption option, int qty) onQuantity;
  final void Function(AddonGroup group, String text) onText;
  final void Function(AddonGroup group) onLimitReached;

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
        // The design puts the choices directly under the dish's own details
        // and above everything that is only reference material.
        for (final group in groups) ...[
          const SizedBox(height: AppTokens.space16),
          AddonGroupCard(
            group: group,
            selection: selection,
            showError: showErrors && selection.unanswered([group]).isNotEmpty,
            onToggle: (option) => onToggle(group, option),
            onQuantity: (option, qty) => onQuantity(group, option, qty),
            onText: (text) => onText(group, text),
            onLimitReached: () => onLimitReached(group),
          ),
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
    required this.groups,
    required this.selection,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onAdd,
  });

  final Product product;
  final List<AddonGroup> groups;
  final AddonSelection selection;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final orderable = product.isOrderable;
    final prices = product.prices;
    // A variable dish has no single price until a variation is chosen, so the
    // bar shows no total rather than a misleading one.
    final showTotal = !prices.hasRange;
    final unanswered = selection.unanswered(groups);

    // The live preview the design shows on the button. A **preview**: the
    // plugin can discount a line server-side, so the cart's own total is the
    // only charged figure — see `CONTEXT.md`.
    final Money unitPrice =
        prices.price + selection.priceDelta(groups, prices.price.currency);
    final lineTotal = unitPrice * quantity;

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
              // Enabled even with a group unanswered: the design keeps the
              // button live and names what is missing when it is pressed,
              // which beats a dead button the customer has to deduce.
              onPressed: orderable ? onAdd : null,
              style: unanswered.isEmpty
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: palette.brand.withValues(alpha: 0.75),
                    ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    switch ((orderable, unanswered.isNotEmpty)) {
                      (false, _) => 'Unavailable',
                      (true, true) =>
                        'Select ${unanswered.first.title.toLowerCase()}',
                      (true, false) =>
                        prices.hasRange ? 'Choose options' : 'Add to cart',
                    },
                  ),
                  // The total stays on the button while a group is still
                  // open, as the design has it, so it is visibly a running
                  // figure rather than something that appears at the end.
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

import 'package:flutter/material.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// Food tags on a dish, as small tinted pills.
///
/// Backed by WooCommerce's `product_tag`. A handful of common dietary tags get
/// a leading icon, matched on slug so renaming the label in WordPress does not
/// break it. Anything else renders as a plain pill, so an unexpected tag still
/// looks deliberate.
class FoodTags extends StatelessWidget {
  const FoodTags({required this.tags, super.key});

  final List<ProductTag> tags;

  /// Slug to icon. Kept deliberately short — guessing at icons for arbitrary
  /// store-defined tags produces worse results than no icon.
  static const _icons = <String, IconData>{
    'vegetarian': Icons.eco_outlined,
    'vegan': Icons.spa_outlined,
    'spicy': Icons.local_fire_department_outlined,
    'gluten-free': Icons.grain_outlined,
    'healthy': Icons.favorite_outline,
    'popular': Icons.trending_up,
    'new': Icons.auto_awesome_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space10,
              vertical: AppTokens.space6,
            ),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(AppTokens.radiusChip),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_icons[tag.slug] case final icon?) ...[
                  Icon(icon, size: 13, color: palette.muted),
                  const SizedBox(width: AppTokens.space4),
                ],
                Text(
                  tag.name,
                  style: text.labelMedium?.copyWith(color: palette.muted2),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

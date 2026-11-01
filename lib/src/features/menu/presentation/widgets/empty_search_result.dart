import 'package:flutter/material.dart';

import '../../../../core/store_api/models/menu_category.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// Shown when a search returns no dishes.
///
/// Offers any category whose name relates to the term, because WooCommerce
/// searches product names only — so "pizza" finds nothing even with a full
/// Pizza category. Without this the customer's only option is to retype.
class EmptySearchResult extends StatelessWidget {
  const EmptySearchResult({
    required this.query,
    required this.suggestions,
    required this.onBrowseCategory,
    super.key,
  });

  final String query;
  final List<MenuCategory> suggestions;
  final ValueChanged<MenuCategory> onBrowseCategory;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          children: [
            Icon(Icons.search_off_outlined, size: 40, color: palette.muted),
            const SizedBox(height: AppTokens.space12),
            Text(
              'No dishes match “$query”.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: palette.muted),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space20),
              Text(
                suggestions.length == 1
                    ? 'Try this category instead'
                    : 'Try these categories instead',
                style: text.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: AppTokens.space10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppTokens.space8,
                runSpacing: AppTokens.space8,
                children: [
                  for (final category in suggestions)
                    _SuggestionButton(
                      category: category,
                      onTap: () => onBrowseCategory(category),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({required this.category, required this.onTap});

  final MenuCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final count = category.count;

    return Material(
      color: palette.tint,
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space12,
            vertical: AppTokens.space8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category.name,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.brand,
                ),
              ),
              const SizedBox(width: AppTokens.space6),
              Text(
                count == 1 ? '1 dish' : '$count dishes',
                style: text.labelMedium?.copyWith(color: palette.brand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

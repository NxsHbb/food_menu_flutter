import 'package:flutter/material.dart';

import '../../../../core/store_api/models/menu_category.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// The design's horizontally scrolling category row.
///
/// Leads with an "All" chip so clearing a filter is one tap and does not
/// depend on remembering that tapping the selected chip again clears it.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<MenuCategory> categories;

  /// Null means "All".
  final int? selectedId;

  /// Receives null for "All".
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppTokens.space8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Chip(
              label: 'All',
              selected: selectedId == null,
              onTap: () => onSelected(null),
            );
          }
          final category = categories[index - 1];
          return _Chip(
            label: category.name,
            selected: category.id == selectedId,
            onTap: () => onSelected(category.id),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Material(
      color: selected ? palette.brand : palette.chip,
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space14),
          child: Center(
            child: Text(
              label,
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

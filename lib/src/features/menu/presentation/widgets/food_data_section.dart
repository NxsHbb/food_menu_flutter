import 'package:flutter/material.dart';

import '../../../../core/store_api/models/product.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// Ingredients or nutrition facts on the dish detail screen.
///
/// Rendered as a labelled list rather than a table: most rows are short, and a
/// two-column table collapses badly once an ingredient name wraps.
class FoodDataSection extends StatelessWidget {
  const FoodDataSection({
    required this.title,
    required this.rows,
    super.key,
  });

  final String title;
  final List<FoodDataRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium),
        const SizedBox(height: AppTokens.space10),
        Container(
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space14,
            vertical: AppTokens.space4,
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: palette.line),
                _Row(row: rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final FoodDataRow row;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final amount = row.amount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              row.name,
              style: text.bodyMedium?.copyWith(color: palette.muted2),
            ),
          ),
          // An amount is optional in the admin, so a row can be a name alone.
          if (amount.isNotEmpty) ...[
            const SizedBox(width: AppTokens.space12),
            Text(
              amount,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

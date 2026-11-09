import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// One row of the design's account list: a lettered tile, a label, an optional
/// value and a chevron.
///
/// The design groups the rows into a single white card, so a row draws no
/// surface of its own — [AccountRowCard] provides it and the dividers.
class AccountRow extends StatelessWidget {
  const AccountRow({
    required this.mono,
    required this.label,
    required this.onTap,
    this.value,
    super.key,
  });

  /// The design's two-letter tile, e.g. `WL` for Wishlist.
  final String mono;
  final String label;

  /// The right-hand hint — a count, a setting. Omitted when there is nothing
  /// true to say; the design's own placeholder values are not invented here.
  final String? value;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space14,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.tint,
                borderRadius: BorderRadius.circular(AppTokens.radiusControl),
              ),
              child: Text(
                mono,
                style: text.labelMedium?.copyWith(color: palette.brand),
              ),
            ),
            const SizedBox(width: AppTokens.space14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge,
              ),
            ),
            if (value case final value? when value.isNotEmpty) ...[
              const SizedBox(width: AppTokens.space8),
              Text(
                value,
                style: text.bodySmall?.copyWith(color: palette.muted),
              ),
            ],
            const SizedBox(width: AppTokens.space6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The white card the account rows sit in, with hairlines between them.
class AccountRowCard extends StatelessWidget {
  const AccountRowCard({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The design pads the card rather than its first and last row, so
          // the ink splash still runs the full width.
          const SizedBox(height: AppTokens.space6),
          for (final (index, row) in rows.indexed) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppTokens.space16 + 38 + AppTokens.space14,
                color: palette.line,
              ),
            row,
          ],
          const SizedBox(height: AppTokens.space6),
        ],
      ),
    );
  }
}

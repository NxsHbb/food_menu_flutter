import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// The store's "x% off" badge (task 9.2).
///
/// **The text is the store's, not ours.** The plugin publishes both a full
/// phrasing and a compact one, already translated; this draws whichever the
/// caller has room for. Composing "${percentage}% off" in Dart would put one
/// untranslatable string in an app whose every other word comes from the
/// server.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({required this.text, this.compact = false, super.key});

  final String text;

  /// Smaller, for a card corner rather than a line of its own.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final palette = AppPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.brand,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppTokens.space8 : AppTokens.space10,
          vertical: compact ? 3 : AppTokens.space4,
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (compact
                  ? Theme.of(context).textTheme.labelSmall
                  : Theme.of(context).textTheme.labelMedium)
              ?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

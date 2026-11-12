import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Five stars, filled to a rating.
///
/// Read-only. Half stars are drawn because an **average** is rarely a whole
/// number — a dish at 4.67 shown as four stars understates it and as five
/// overstates it. A single review's own rating is always whole, so this looks
/// the same either way there.
class StarRating extends StatelessWidget {
  const StarRating({
    required this.rating,
    this.size = 16,
    super.key,
  });

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            switch (rating - star) {
              >= 0 => Icons.star_rounded,
              >= -0.5 => Icons.star_half_rounded,
              _ => Icons.star_outline_rounded,
            },
            size: size,
            color: palette.star,
          ),
      ],
    );
  }
}

/// Five stars the customer taps, for the review form.
class StarPicker extends StatelessWidget {
  const StarPicker({
    required this.rating,
    required this.onChanged,
    this.size = 34,
    super.key,
  });

  /// 0 for nothing chosen yet.
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            onPressed: () => onChanged(star),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: size + 8,
              height: size + 8,
            ),
            // Named so a test and a screen reader can both tell which is
            // which — five identical stars are otherwise indistinguishable.
            tooltip: '$star star${star == 1 ? '' : 's'}',
            icon: Icon(
              star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: star <= rating ? palette.star : palette.muted,
            ),
          ),
      ],
    );
  }
}

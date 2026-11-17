import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_palette.dart';

/// The store's Price Label, shown where a price would be (task 14.6).
///
/// **Printed exactly as typed.** The store wrote the whole string — numbers,
/// separators, the word "from" if it wanted one — so nothing here adds a
/// currency symbol or reformats it. A dish whose price is "Market price" or
/// "Small 5.95 | Large 6.50" is the entire point of the feature.
///
/// It replaces the price block rather than joining it: a label beside a
/// number is two answers to one question, and the store already chose which
/// one it wants read.
class PriceLabelText extends StatelessWidget {
  const PriceLabelText({required this.label, this.style, super.key});

  final String label;

  /// The price style of whichever surface this is standing in for, so the
  /// label sits at the same weight as the number it replaced.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Text(
      label,
      // **Two lines, not one.** "Small 5.95 | Large 6.50" is longer than any
      // price, and a dish card at phone width has about half a line for it.
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(color: palette.brand),
    );
  }
}

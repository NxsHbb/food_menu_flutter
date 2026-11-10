import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// One section of the checkout, in the design's white rounded panel.
///
/// The design stacks the whole screen out of these, so they are one widget
/// rather than a decoration repeated per section.
class CheckoutCard extends StatelessWidget {
  const CheckoutCard({required this.child, this.padding, super.key});

  final Widget child;

  /// Tighter on the address row, which carries its own tile.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCardLarge),
        border: Border.all(color: palette.line),
      ),
      child: child,
    );
  }
}

/// A section's bold heading, as the design sets them.
class CheckoutSectionTitle extends StatelessWidget {
  const CheckoutSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// The design's inner-screen header: a bordered back button and a title on a
/// white bar, used by screens that sit inside a tab rather than over it.
///
/// Extracted from the wishlist screen when the address book needed the same
/// bar. Screens that cover the tabs — a dish, checkout — use their own
/// chrome instead.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    this.onBack,
    this.trailing,
    super.key,
  });

  final String title;

  /// Where back goes when there is nothing to pop, which a deep link can
  /// cause. Without it the button would be dead on arrival.
  final VoidCallback? onBack;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space10,
            AppTokens.space16,
            AppTokens.space14,
          ),
          child: Row(
            children: [
              _BackButton(onBack: onBack),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      side: BorderSide(color: palette.line),
    );

    return Material(
      color: palette.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            onBack?.call();
          }
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.chevron_left_rounded, size: 24, color: palette.ink),
        ),
      ),
    );
  }
}

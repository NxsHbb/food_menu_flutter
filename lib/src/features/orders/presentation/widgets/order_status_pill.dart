import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// The design's status pill, on a history row and on the order header.
///
/// **The design hard-codes a background and foreground per status**, for the
/// five it knows about. That cannot hold here: the plugin lets a store invent
/// statuses, so the app would have no pair for "Out for delivery" at one shop
/// and "In the oven" at the next. The server sends one colour per status
/// instead — its own, honouring the store's admin overrides — and the pair is
/// derived from it.
///
/// Falls back to the muted chip when the store has no colour for a status, so
/// an unknown one is plain rather than invisible.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;

  /// `#rrggbb` from the server. May be empty.
  final String color;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final parsed = parseHexColor(color);

    final foreground = parsed ?? palette.muted2;
    final background = parsed == null
        ? palette.chip
        // Low enough to read as a tint rather than a second colour, which is
        // what the design's hand-picked pairs do.
        : parsed.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space10,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// `#rrggbb` to a [Color], or null for anything else.
///
/// Six digits only. CSS's eight-digit form is `#rrggbbaa`, where `Color(int)`
/// reads `0xaarrggbb` — accepting it would silently paint the status in the
/// wrong colour, which is worse than not accepting it. The plugin sends six.
///
/// Null rather than a guess: a malformed colour falls back to the theme
/// instead of painting something arbitrary over a status being read.
Color? parseHexColor(String value) {
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);

  if (hex.length != 6) return null;

  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xff000000 | parsed);
}

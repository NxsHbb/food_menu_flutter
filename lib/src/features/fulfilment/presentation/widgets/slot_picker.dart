import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/slots.dart';

/// The design's time row: a chip per choosable time, ASAP leading.
///
/// Everything drawn here was decided server-side. Past times never arrive, so
/// nothing is filtered by the device clock; a full or blocked slot arrives
/// marked, and the store's own sentence explains it.
///
/// Laid out as the design's **single scrolling row**. Wrapping was tried and
/// is wrong here: a store open all day at a half-hour interval offers nearly
/// forty slots, and wrapped they ran down the screen and pushed the rest of
/// the checkout out of sight. A row keeps the section one line tall whatever
/// the store's hours, and gives each chip its natural width, which a delivery
/// window — "1:00 pm – 2:00 pm" — needs.
class SlotPicker extends StatelessWidget {
  const SlotPicker({
    required this.slots,
    required this.selected,
    required this.onSelected,
    required this.onUnavailable,
    super.key,
  });

  final SlotList slots;

  /// Resolved against the list, so it is never a slot that is gone.
  final Slot? selected;

  final ValueChanged<Slot> onSelected;

  /// Tapping an unavailable chip explains it rather than doing nothing — the
  /// reason is the useful part, and a chip that ignores taps reads as broken.
  final ValueChanged<Slot> onUnavailable;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return _ClosedNotice(message: slots.message);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // The card's own padding would otherwise clip the first and last chip
      // against the edge as the row scrolls.
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final slot in slots.slots)
            Padding(
              padding: EdgeInsets.only(
                right: slot == slots.slots.last ? 0 : AppTokens.space8,
              ),
              child: _SlotChip(
                slot: slot,
                selected: slot.startMinutes == selected?.startMinutes,
                onTap: () =>
                    slot.available ? onSelected(slot) : onUnavailable(slot),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final Slot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final available = slot.available;

    final background = selected
        ? palette.tint
        : (available ? palette.card : palette.chip);
    final foreground = selected
        ? palette.brand
        : (available ? palette.ink : palette.muted);

    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: selected ? palette.brand : palette.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space14,
              vertical: AppTokens.space10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot.label,
                  maxLines: 1,
                  softWrap: false,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                    // A struck-through time says "not this one" at a glance,
                    // where grey alone can read as merely unselected.
                    decoration: available ? null : TextDecoration.lineThrough,
                  ),
                ),
                // Only worth saying when it is nearly gone. "3 left" on every
                // chip is noise; it earns its place at one or two.
                if (available && slot.remaining != null && slot.remaining! <= 2)
                  Padding(
                    padding: const EdgeInsets.only(left: AppTokens.space8),
                    child: Text(
                      '${slot.remaining}',
                      style: text.labelSmall?.copyWith(
                        color: palette.warnForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the date has nothing to choose, with the store's own words.
class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.space14),
      decoration: BoxDecoration(
        color: palette.warnBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 18,
            color: palette.warnForeground,
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Text(
              // Falls back only if the server sent none, which it does not.
              message ?? 'No times are available.',
              style: text.bodySmall?.copyWith(color: palette.warnForeground),
            ),
          ),
        ],
      ),
    );
  }
}

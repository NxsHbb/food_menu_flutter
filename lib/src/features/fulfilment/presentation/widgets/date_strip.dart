import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_tokens.dart';

/// The dates a customer may order for, as a scrolling row of chips.
///
/// Drawn only when the store takes orders for more than one date — with
/// `fmp_preorder_max_days` at its default of zero there is exactly one, and a
/// strip of one chip is a label pretending to be a choice.
///
/// **Which dates exist is the server's answer**, from `first_date` and
/// `last_date` on `/app/slots`. What each one is called is this app's, because
/// the route names only the date it was asked about.
///
/// A closed day inside the range is **still offered**. The app cannot know a
/// store's weekly closures without asking, and a chip that answers "Closed on
/// Mondays" in the store's own words beats one silently missing.
class DateStrip extends StatelessWidget {
  const DateStrip({
    required this.dates,
    required this.selected,
    required this.storeToday,
    required this.onSelected,
    super.key,
  });

  /// `Y-m-d`, earliest first.
  final List<String> dates;

  /// The date currently being shown, `Y-m-d`.
  final String selected;

  /// The **store's** today, not the device's: the two disagree whenever the
  /// phone is in another timezone, and "Today" has to mean the kitchen's.
  final String? storeToday;

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // As the slot row: the card's padding would clip the end chips.
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final date in dates)
            Padding(
              padding: EdgeInsets.only(
                right: date == dates.last ? 0 : AppTokens.space8,
              ),
              child: _DateChip(
                label: dateChipLabel(date, storeToday: storeToday),
                selected: date == selected,
                onTap: () => onSelected(date),
              ),
            ),
        ],
      ),
    );
  }
}

/// What one date is called on a chip: "Today", "Tomorrow", or "Thu 13 Nov".
///
/// Relative to the **store's** today where it is known. With no store date to
/// compare against, every chip takes the dated form rather than this guessing
/// from the phone, which would read "Today" on the wrong row for a customer
/// ordering from another timezone.
String dateChipLabel(String date, {String? storeToday}) {
  final when = DateTime.tryParse(date);
  if (when == null) return date;

  final today = DateTime.tryParse(storeToday ?? '');

  if (today != null) {
    final days = DateTime.utc(when.year, when.month, when.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
  }

  return '${_weekdays[when.weekday - 1]} ${when.day} ${_months[when.month - 1]}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class _DateChip extends StatelessWidget {
  const _DateChip({
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

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.tint : palette.card,
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
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? palette.brand : palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

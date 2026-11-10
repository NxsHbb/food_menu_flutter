/// Dates as the design writes them: "Today, 2:02 PM".
///
/// Hand-rolled rather than `intl`, which is not a dependency and would be a
/// large one to add for two lines of output. That is defensible only because
/// every other string in this app is hard-coded English too — when the app is
/// localised, this goes with them rather than being the one exception.
///
/// **Always rendered in the device's time zone.** The server sends an offset
/// ("…T08:59:40+00:00"), and an order placed at 2pm local must not read as
/// 8am because the store keeps its books in UTC.
library;

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

/// "Today, 2:02 PM", "Yesterday, 2:02 PM", "12 Mar, 2:02 PM" or "12 Mar 2025".
///
/// [now] is injectable so a test can say what day it is instead of waiting
/// for midnight to prove the boundary.
String relativeDateTime(DateTime when, {DateTime? now}) {
  final local = when.toLocal();
  final today = (now ?? DateTime.now()).toLocal();

  final days = _midnight(today).difference(_midnight(local)).inDays;

  if (days == 0) return 'Today, ${formatTime(local)}';
  if (days == 1) return 'Yesterday, ${formatTime(local)}';

  final date = '${local.day} ${_months[local.month - 1]}';

  // The year only once it stops being obvious, which keeps the common case
  // short without ever being ambiguous.
  if (local.year != today.year) return '$date ${local.year}';

  return '$date, ${formatTime(local)}';
}

/// "2:02 PM". Midnight is 12 AM and noon is 12 PM, which `hour % 12` alone
/// gets wrong in both cases.
String formatTime(DateTime when) {
  final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final minute = when.minute.toString().padLeft(2, '0');

  return '$hour:$minute ${when.hour < 12 ? 'AM' : 'PM'}';
}

/// Strips the time, so "yesterday" means a calendar day and not 24 hours.
DateTime _midnight(DateTime when) => DateTime(when.year, when.month, when.day);

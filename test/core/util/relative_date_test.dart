import 'package:flutter_test/flutter_test.dart';
import 'package:food_menu/src/core/util/relative_date.dart';

void main() {
  final now = DateTime(2026, 11, 10, 15, 30);

  group('formatTime', () {
    test('renders a twelve-hour clock', () {
      expect(formatTime(DateTime(2026, 1, 1, 14, 2)), '2:02 PM');
      expect(formatTime(DateTime(2026, 1, 1, 9, 5)), '9:05 AM');
    });

    test('midnight is 12 AM and noon is 12 PM', () {
      // `hour % 12` is zero for both, which would read as "0:00".
      expect(formatTime(DateTime(2026, 1, 1, 0, 0)), '12:00 AM');
      expect(formatTime(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    });

    test('pads the minute', () {
      expect(formatTime(DateTime(2026, 1, 1, 13, 7)), '1:07 PM');
    });
  });

  group('relativeDateTime', () {
    test('today is named, not dated', () {
      expect(
        relativeDateTime(DateTime(2026, 11, 10, 14, 2), now: now),
        'Today, 2:02 PM',
      );
    });

    test('yesterday too', () {
      expect(
        relativeDateTime(DateTime(2026, 11, 9, 23, 59), now: now),
        'Yesterday, 11:59 PM',
      );
    });

    test('yesterday is a calendar day, not twenty-four hours', () {
      // Ten minutes earlier, but the day before: "Yesterday", not "Today".
      expect(
        relativeDateTime(DateTime(2026, 11, 9, 15, 20), now: now),
        startsWith('Yesterday'),
      );
    });

    test('earlier this year keeps the time and drops the year', () {
      expect(
        relativeDateTime(DateTime(2026, 3, 12, 14, 2), now: now),
        '12 Mar, 2:02 PM',
      );
    });

    test('another year is dated and the time dropped', () {
      // By then the time of day has stopped being the useful part.
      expect(
        relativeDateTime(DateTime(2025, 3, 12, 14, 2), now: now),
        '12 Mar 2025',
      );
    });

    test('a server offset is rendered in the device time zone', () {
      final utc = DateTime.utc(2026, 11, 10, 9, 0);

      // The assertion has to be time-zone agnostic to run anywhere, so it
      // checks the conversion happened rather than naming an hour.
      expect(
        relativeDateTime(utc, now: now),
        relativeDateTime(utc.toLocal(), now: now),
      );
    });
  });
}

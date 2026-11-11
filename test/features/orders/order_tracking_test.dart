import 'package:flutter_test/flutter_test.dart';

import 'fake_orders_repository.dart';

void main() {
  group('OrderTracking', () {
    test('reads the stages and where the order has got to', () {
      final tracking = trackingFixture();

      expect(tracking.stages, hasLength(4));
      expect(tracking.step, 1);
      expect(tracking.current?.label, 'Prepping');
      expect(tracking.stages[1].at, isNotEmpty);
      // A stage still to come carries no time: there is nothing to time yet.
      expect(tracking.stages[2].reached, isFalse);
      expect(tracking.stages[2].at, isEmpty);
    });

    test('fills the strip by stage, not by status', () {
      // Two reached of four stages is one third of the way between the first
      // and the last, which is what the strip measures.
      expect(trackingFixture().progress, closeTo(1 / 3, 0.001));

      expect(
        trackingFixture(
          stages: const [
            ('processing', 'Processing', true),
            ('completed', 'Completed', true),
          ],
        ).progress,
        1,
      );
    });

    test('a failed order fills nothing', () {
      final cancelled = trackingFixture(
        status: 'cancelled',
        statusLabel: 'Cancelled',
        isActive: false,
        isFailed: true,
        stages: const [
          ('processing', 'Processing', true),
          ('cancelled', 'Cancelled', true),
        ],
      );

      // Reached its last stage, so by arithmetic the strip would be full. The
      // strip promises food on its way and a cancelled order has none coming,
      // so it reads empty instead.
      expect(cancelled.step, 1);
      expect(cancelled.progress, 0);
    });

    test('a single stage is full rather than a division by zero', () {
      final one = trackingFixture(
        stages: const [('processing', 'Processing', true)],
      );

      expect(one.progress, 1);
      expect(one.progress.isFinite, isTrue);
    });

    test('nothing recorded is step -1, not step 0', () {
      final none = trackingFixture(stages: const []);

      // Step 0 would read as "the first stage is done".
      expect(none.step, -1);
      expect(none.current, isNull);
      expect(none.progress, 0);
    });

    test('an empty payload says there is no timeline', () {
      final empty = OrderTracking.fromJson(const {});

      expect(empty.hasTimeline, isFalse);
      expect(empty.stages, isEmpty);
      expect(empty.step, -1);
      expect(empty.isActive, isFalse);
      expect(empty.isFailed, isFalse);
    });

    test('a note rides along only when the server sent one', () {
      expect(trackingFixture().current?.note, isEmpty);
      expect(
        trackingFixture(note: 'Kitchen has it').current?.note,
        'Kitchen has it',
      );
    });
  });

  group('OrderProgress', () {
    test('reads the pair a history row draws its strip from', () {
      final progress = OrderProgress.tryFromJson(
        const {'step': 1, 'stage_count': 4},
      );

      expect(progress, isNotNull);
      expect(progress!.fraction, closeTo(1 / 3, 0.001));
    });

    test('is absent rather than zero when there is nothing to draw', () {
      // The store has the timeline off, or the order predates it. A bar stuck
      // at the left would read as an order nobody has started.
      expect(OrderProgress.tryFromJson(null), isNull);
      expect(OrderProgress.tryFromJson('nonsense'), isNull);
      expect(OrderProgress.tryFromJson(const {}), isNull);
      expect(
        OrderProgress.tryFromJson(const {'step': -1, 'stage_count': 4}),
        isNull,
      );
      expect(
        OrderProgress.tryFromJson(const {'step': 0, 'stage_count': 0}),
        isNull,
      );
    });

    test('a one-stage order is full, and nothing exceeds full', () {
      expect(
        OrderProgress.tryFromJson(const {'step': 0, 'stage_count': 1})!.fraction,
        1,
      );
      // A step past the end would otherwise fill beyond the track.
      expect(
        OrderProgress.tryFromJson(const {'step': 9, 'stage_count': 3})!.fraction,
        1,
      );
    });
  });
}

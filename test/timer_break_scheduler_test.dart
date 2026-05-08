import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/scheduler/domain/timer_break_scheduler.dart';

void main() {
  test(
    'fires at the scheduled time and can be started again for later cycles',
    () {
      fakeAsync((async) {
        final DateTime start = DateTime(2026, 1, 1, 9);
        final List<DateTime> firedAt = <DateTime>[];
        final TimerBreakScheduler scheduler = TimerBreakScheduler(
          now: () => start.add(async.elapsed),
        );

        scheduler.ticks.listen(firedAt.add);

        scheduler.start(const OverlaySchedule(interval: Duration(minutes: 15)));

        expect(scheduler.nextTriggerAt, start.add(const Duration(minutes: 15)));

        async.elapse(const Duration(minutes: 15));

        expect(firedAt, <DateTime>[start.add(const Duration(minutes: 15))]);
        expect(scheduler.nextTriggerAt, isNull);

        scheduler.start(const OverlaySchedule(interval: Duration(minutes: 30)));

        expect(scheduler.nextTriggerAt, start.add(const Duration(minutes: 45)));

        async.elapse(const Duration(minutes: 30));

        expect(firedAt, <DateTime>[
          DateTime(2026, 1, 1, 9, 15),
          DateTime(2026, 1, 1, 9, 45),
        ]);
      });
    },
  );

  test('pause and resume preserves the remaining delay', () {
    fakeAsync((async) {
      final DateTime start = DateTime(2026, 1, 1, 9);
      final List<DateTime> firedAt = <DateTime>[];
      final TimerBreakScheduler scheduler = TimerBreakScheduler(
        now: () => start.add(async.elapsed),
      );

      scheduler.ticks.listen(firedAt.add);

      scheduler.start(const OverlaySchedule(interval: Duration(minutes: 20)));

      async.elapse(const Duration(minutes: 5));
      scheduler.pause();

      expect(scheduler.nextTriggerAt, isNull);

      async.elapse(const Duration(hours: 1));
      expect(firedAt, isEmpty);

      scheduler.resume();
      expect(
        scheduler.nextTriggerAt,
        start.add(const Duration(hours: 1, minutes: 20)),
      );

      async.elapse(const Duration(minutes: 14));
      expect(firedAt, isEmpty);

      async.elapse(const Duration(minutes: 1));
      expect(firedAt, <DateTime>[
        start.add(const Duration(hours: 1, minutes: 20)),
      ]);
    });
  });
}

import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

abstract class SchedulingStrategy {
  DateTime nextTriggerAt({
    required DateTime now,
    required OverlaySchedule schedule,
  });
}

class HourlySchedulingStrategy implements SchedulingStrategy {
  const HourlySchedulingStrategy();

  @override
  DateTime nextTriggerAt({
    required DateTime now,
    required OverlaySchedule schedule,
  }) {
    if (schedule.startImmediately) {
      return now;
    }

    return now.add(schedule.interval);
  }
}

import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/scheduler/domain/break_scheduler.dart';

class SchedulerService {
  SchedulerService({required BreakScheduler scheduler})
    : _scheduler = scheduler;

  final BreakScheduler _scheduler;

  Stream<DateTime> get ticks => _scheduler.ticks;

  DateTime? get nextTriggerAt => _scheduler.nextTriggerAt;

  Future<void> schedule(OverlaySchedule schedule) {
    return _scheduler.start(schedule);
  }

  Future<void> reschedule(OverlaySchedule schedule) async {
    await _scheduler.stop();
    await _scheduler.start(schedule);
  }

  Future<void> stop() {
    return _scheduler.stop();
  }

  Future<void> pause() {
    return _scheduler.pause();
  }

  Future<void> resume() {
    return _scheduler.resume();
  }
}

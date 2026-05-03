import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

abstract class BreakScheduler {
  Stream<DateTime> get ticks;

  Future<void> start(OverlaySchedule schedule);

  Future<void> stop();

  Future<void> pause();

  Future<void> resume();

  DateTime? get nextTriggerAt;
}

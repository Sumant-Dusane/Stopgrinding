import 'dart:async';

import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/scheduler/domain/break_scheduler.dart';
import 'package:stopgrinding/features/scheduler/domain/scheduling_strategy.dart';

class TimerBreakScheduler implements BreakScheduler {
  TimerBreakScheduler({
    SchedulingStrategy strategy = const HourlySchedulingStrategy(),
    DateTime Function()? now,
  }) : _strategy = strategy,
       _now = now ?? DateTime.now;

  final SchedulingStrategy _strategy;
  final DateTime Function() _now;
  final StreamController<DateTime> _ticksController =
      StreamController<DateTime>.broadcast();

  Timer? _timer;
  DateTime? _nextTriggerAt;
  Duration? _remaining;

  @override
  Stream<DateTime> get ticks => _ticksController.stream;

  @override
  DateTime? get nextTriggerAt => _nextTriggerAt;

  @override
  Future<void> start(OverlaySchedule schedule) async {
    _remaining = null;
    _scheduleNextTick(
      target: _strategy.nextTriggerAt(now: _now(), schedule: schedule),
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _nextTriggerAt = null;
    _remaining = null;
  }

  @override
  Future<void> pause() async {
    if (_timer == null || _nextTriggerAt == null) {
      return;
    }

    _remaining = _nextTriggerAt!.difference(_now());
    if (_remaining!.isNegative) {
      _remaining = Duration.zero;
    }
    _timer?.cancel();
    _timer = null;
    _nextTriggerAt = null;
  }

  @override
  Future<void> resume() async {
    final Duration? remaining = _remaining;
    if (remaining == null) {
      return;
    }

    _remaining = null;
    _scheduleNextTick(target: _now().add(remaining));
  }

  void _scheduleNextTick({required DateTime target}) {
    _timer?.cancel();
    _nextTriggerAt = target;
    final Duration delay = target.difference(_now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      final DateTime firedAt = _now();
      _timer = null;
      _nextTriggerAt = null;
      _ticksController.add(firedAt);
    });
  }
}

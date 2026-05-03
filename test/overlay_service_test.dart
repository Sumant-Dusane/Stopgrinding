import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:stopgrinding/features/overlay/domain/overlay_controller.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/scheduler/domain/break_scheduler.dart';
import 'package:stopgrinding/features/scheduler/domain/scheduler_service.dart';
import 'package:stopgrinding/features/settings/domain/in_memory_overlay_settings_repository.dart';

void main() {
  test(
    'initialization loads settings and schedules the next overlay',
    () async {
      final _FakeOverlayController controller = _FakeOverlayController();
      final _FakeBreakScheduler scheduler = _FakeBreakScheduler();
      final OverlayService service = OverlayService(
        controller: controller,
        schedulerService: SchedulerService(scheduler: scheduler),
        settingsRepository: InMemoryOverlaySettingsRepository(),
      );

      await service.initialize();

      expect(service.state.isInitialized, isTrue);
      expect(service.state.lifecycle, OverlayState.scheduled);
      expect(service.state.nextTriggerAt, scheduler.nextTriggerAt);
      expect(controller.updatedSettings, isNotNull);
      expect(service.state.lastResult, isNull);
    },
  );

  test(
    'show and dismiss flow moves through explicit lifecycle states',
    () async {
      final _FakeOverlayController controller = _FakeOverlayController();
      final _FakeBreakScheduler scheduler = _FakeBreakScheduler();
      final OverlayService service = OverlayService(
        controller: controller,
        schedulerService: SchedulerService(scheduler: scheduler),
        settingsRepository: InMemoryOverlaySettingsRepository(),
      );
      final List<OverlayState> transitions = <OverlayState>[];

      service.events.listen((OverlayEvent event) {
        if (event.type == OverlayEventType.stateChanged &&
            event.state != null) {
          transitions.add(event.state!);
        }
      });

      await service.initialize();
      await service.showOverlay();

      expect(service.state.lifecycle, OverlayState.preparing);

      controller.emit(
        OverlayEvent(
          type: OverlayEventType.shown,
          state: OverlayState.visible,
          session: OverlaySession(
            id: 'session-1',
            startedAt: DateTime(2026, 1, 1, 10),
            displayTargets: const <DisplayTarget>[
              DisplayTarget(id: 'display-1', name: 'Built-in', isPrimary: true),
            ],
            settings: OverlaySettings.defaults(),
          ),
          occurredAt: DateTime(2026, 1, 1, 10),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.state.lifecycle, OverlayState.visible);
      expect(service.state.lastResult?.type, OverlayResultType.shown);

      controller.emit(
        OverlayEvent(
          type: OverlayEventType.dismissed,
          state: OverlayState.dismissed,
          dismissReason: OverlayDismissReason.timeout,
          occurredAt: DateTime(2026, 1, 1, 10, 2),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(service.state.lifecycle, OverlayState.scheduled);
      expect(service.state.lastDismissReason, isNull);
      expect(service.state.lastResult?.type, OverlayResultType.dismissed);
      expect(
        service.state.lastResult?.dismissReason,
        OverlayDismissReason.timeout,
      );
      expect(
        transitions,
        containsAllInOrder(<OverlayState>[
          OverlayState.scheduled,
          OverlayState.preparing,
          OverlayState.visible,
          OverlayState.dismissed,
          OverlayState.cooldown,
          OverlayState.scheduled,
        ]),
      );
    },
  );
}

class _FakeOverlayController implements OverlayController {
  final StreamController<OverlayEvent> _eventsController =
      StreamController<OverlayEvent>.broadcast();

  OverlayStatus status = const OverlayStatus(state: OverlayState.idle);
  OverlaySettings? updatedSettings;
  OverlaySettings? shownSettings;
  OverlayDismissReason? hiddenReason;

  @override
  Stream<OverlayEvent> get events => _eventsController.stream;

  void emit(OverlayEvent event) {
    _eventsController.add(event);
  }

  @override
  Future<OverlayStatus> getStatus() async => status;

  @override
  Future<void> hideOverlay({
    OverlayDismissReason reason = OverlayDismissReason.hiddenByApp,
  }) async {
    hiddenReason = reason;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshDisplays() async {}

  @override
  Future<void> showOverlay(OverlaySettings settings) async {
    shownSettings = settings;
  }

  @override
  Future<void> updateSettings(OverlaySettings settings) async {
    updatedSettings = settings;
  }
}

class _FakeBreakScheduler implements BreakScheduler {
  final StreamController<DateTime> _ticksController =
      StreamController<DateTime>.broadcast();

  @override
  DateTime? nextTriggerAt;

  @override
  Stream<DateTime> get ticks => _ticksController.stream;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> start(OverlaySchedule schedule) async {
    nextTriggerAt = DateTime(2026, 1, 1, 11);
  }

  @override
  Future<void> stop() async {
    nextTriggerAt = null;
  }
}

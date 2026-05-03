import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stopgrinding/features/overlay/domain/overlay_controller.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_flow_state.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/scheduler/domain/scheduler_service.dart';
import 'package:stopgrinding/features/settings/domain/overlay_settings_repository.dart';

class OverlayService extends ChangeNotifier {
  OverlayService({
    required OverlayController controller,
    required SchedulerService schedulerService,
    required OverlaySettingsRepository settingsRepository,
  }) : _controller = controller,
       _schedulerService = schedulerService,
       _settingsRepository = settingsRepository {
    _controllerEventsSubscription = _controller.events.listen(_handleEvent);
    _schedulerTicksSubscription = _schedulerService.ticks.listen(
      _handleScheduledTick,
    );
  }

  final OverlayController _controller;
  final SchedulerService _schedulerService;
  final OverlaySettingsRepository _settingsRepository;
  final StreamController<OverlayEvent> _eventsController =
      StreamController<OverlayEvent>.broadcast();

  late final StreamSubscription<OverlayEvent> _controllerEventsSubscription;
  late final StreamSubscription<DateTime> _schedulerTicksSubscription;

  OverlayFlowState _state = OverlayFlowState.initial();
  bool _isInitializing = false;

  OverlayFlowState get state => _state;

  Stream<OverlayEvent> get events => _eventsController.stream;

  Future<void> initialize() async {
    if (_state.isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      final OverlaySettings settings = await _settingsRepository.load();
      await _controller.initialize();
      await _controller.updateSettings(settings);
      final OverlayStatus status = await _controller.getStatus();

      _updateState(
        _state.copyWith(
          settings: settings,
          displays: status.activeSession?.displayTargets ?? _state.displays,
          isInitialized: true,
        ),
      );

      if (status.state == OverlayState.visible &&
          status.activeSession != null) {
        _transitionTo(
          OverlayState.visible,
          activeSession: status.activeSession,
          nextTriggerAt: null,
        );
        return;
      }

      await _scheduleNext(settings.schedule);
    } catch (error) {
      _fail(error);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> showOverlay() async {
    if (_state.isOverlayActive) {
      return;
    }

    try {
      await _schedulerService.stop();
      await _triggerOverlay();
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> dismissOverlay({
    OverlayDismissReason reason = OverlayDismissReason.hiddenByApp,
  }) async {
    if (!_state.isOverlayActive) {
      return;
    }

    try {
      await _controller.hideOverlay(reason: reason);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> saveSettings(OverlaySettings settings) async {
    try {
      await _settingsRepository.save(settings);
      await _controller.updateSettings(settings);
      _updateState(
        _state.copyWith(
          settings: settings,
          lastError: null,
          lastUpdatedAt: DateTime.now(),
        ),
      );

      if (!_state.isOverlayActive) {
        await _scheduleNext(settings.schedule);
      }
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> pause() async {
    await _schedulerService.pause();
    _transitionTo(OverlayState.paused, nextTriggerAt: null);
  }

  Future<void> resume() async {
    await _schedulerService.resume();
    _transitionTo(
      OverlayState.scheduled,
      nextTriggerAt: _schedulerService.nextTriggerAt,
    );
  }

  Future<void> refreshDisplays() {
    return _controller.refreshDisplays();
  }

  Future<void> recover() async {
    try {
      await _controller.refreshDisplays();
      final OverlayStatus status = await _controller.getStatus();

      if (status.state == OverlayState.visible && status.activeSession != null) {
        _transitionTo(
          OverlayState.visible,
          activeSession: status.activeSession,
          displays: status.activeSession?.displayTargets ?? _state.displays,
          nextTriggerAt: null,
          lastError: null,
        );
        return;
      }

      if (!_state.isOverlayActive) {
        await _scheduleNext(_state.settings.schedule);
      }
    } catch (error) {
      _fail(error);
    }
  }

  @override
  void dispose() {
    _controllerEventsSubscription.cancel();
    _schedulerTicksSubscription.cancel();
    _eventsController.close();
    super.dispose();
  }

  Future<void> _handleScheduledTick(DateTime firedAt) async {
    if (_state.isOverlayActive || _state.lifecycle == OverlayState.paused) {
      return;
    }

    await _triggerOverlay(triggeredAt: firedAt);
  }

  Future<void> _triggerOverlay({DateTime? triggeredAt}) async {
    _transitionTo(OverlayState.preparing, nextTriggerAt: null);
    await _controller.showOverlay(_state.settings);
    _updateState(_state.copyWith(lastUpdatedAt: triggeredAt ?? DateTime.now()));
  }

  Future<void> _scheduleNext(OverlaySchedule schedule) async {
    await _schedulerService.reschedule(schedule);
    _transitionTo(
      OverlayState.scheduled,
      nextTriggerAt: _schedulerService.nextTriggerAt,
      activeSession: null,
      lastDismissReason: null,
    );
  }

  void _handleEvent(OverlayEvent event) {
    _eventsController.add(event);

    switch (event.type) {
      case OverlayEventType.shown:
        _transitionTo(
          OverlayState.visible,
          activeSession: event.session,
          displays: event.session?.displayTargets ?? _state.displays,
          nextTriggerAt: null,
          lastResult: OverlayResult(
            type: OverlayResultType.shown,
            occurredAt: event.occurredAt ?? DateTime.now(),
            sessionId: event.session?.id,
          ),
          lastError: null,
        );
        return;
      case OverlayEventType.dismissed:
        unawaited(_handleDismissed(event));
        return;
      case OverlayEventType.failed:
        _fail(event.message ?? 'Overlay request failed');
        return;
      case OverlayEventType.displayTopologyChanged:
        _updateState(
          _state.copyWith(
            displays: event.displays,
            lastUpdatedAt: event.occurredAt ?? DateTime.now(),
          ),
        );
        return;
      case OverlayEventType.stateChanged:
        return;
    }
  }

  Future<void> _handleDismissed(OverlayEvent event) async {
    _transitionTo(
      OverlayState.dismissed,
      activeSession: null,
      nextTriggerAt: null,
      lastResult: OverlayResult(
        type: OverlayResultType.dismissed,
        occurredAt: event.occurredAt ?? DateTime.now(),
        dismissReason: event.dismissReason,
      ),
      lastDismissReason: event.dismissReason,
    );
    _transitionTo(OverlayState.cooldown, nextTriggerAt: null);
    await _scheduleNext(_state.settings.schedule);
  }

  void _transitionTo(
    OverlayState lifecycle, {
    OverlaySession? activeSession,
    DateTime? nextTriggerAt,
    List<DisplayTarget>? displays,
    Object? lastResult = _stateSentinel,
    OverlayDismissReason? lastDismissReason,
    String? lastError,
  }) {
    _updateState(
      _state.copyWith(
        lifecycle: lifecycle,
        activeSession: activeSession,
        nextTriggerAt: nextTriggerAt,
        displays: displays ?? _state.displays,
        lastResult: identical(lastResult, _stateSentinel)
            ? _state.lastResult
            : lastResult as OverlayResult?,
        lastDismissReason: lastDismissReason,
        lastError: lastError,
        lastUpdatedAt: DateTime.now(),
        isInitialized: true,
      ),
    );
    _eventsController.add(
      OverlayEvent(
        type: OverlayEventType.stateChanged,
        state: lifecycle,
        session: activeSession,
        dismissReason: lastDismissReason,
        displays: displays ?? _state.displays,
        message: lastError,
        occurredAt: _state.lastUpdatedAt,
      ),
    );
  }

  void _updateState(OverlayFlowState nextState) {
    _state = nextState;
    notifyListeners();
  }

  void _fail(Object error) {
    _transitionTo(
      OverlayState.idle,
      activeSession: null,
      nextTriggerAt: null,
      lastResult: OverlayResult(
        type: OverlayResultType.failed,
        occurredAt: DateTime.now(),
        message: error.toString(),
      ),
      lastError: error.toString(),
    );
  }
}

const Object _stateSentinel = Object();

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/platform/bridge/overlay_api.g.dart';
import 'package:stopgrinding/platform/bridge/overlay_bridge.dart';

class PigeonOverlayBridge implements OverlayBridge {
  PigeonOverlayBridge({
    OverlayHostApi? hostApi,
    BinaryMessenger? binaryMessenger,
  }) : _hostApi = hostApi ?? OverlayHostApi(binaryMessenger: binaryMessenger) {
    _callbackHandler = _OverlayFlutterCallbackHandler(
      emitEvent: _eventsController.add,
      readSettings: () => _lastKnownSettings,
    );
    OverlayFlutterApi.setUp(_callbackHandler, binaryMessenger: binaryMessenger);
  }

  final OverlayHostApi _hostApi;
  final StreamController<OverlayEvent> _eventsController =
      StreamController<OverlayEvent>.broadcast();
  late final _OverlayFlutterCallbackHandler _callbackHandler;

  OverlaySettings _lastKnownSettings = OverlaySettings.defaults();

  @override
  Stream<OverlayEvent> get events => _eventsController.stream;

  @override
  Future<void> initialize() => _hostApi.initialize();

  @override
  Future<void> showOverlay(OverlaySettings settings) async {
    _lastKnownSettings = settings;
    await _hostApi.showOverlay(
      OverlayRequestDto(
        requestId: _newRequestId(),
        settings: _mapSettings(settings),
        triggeredAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> hideOverlay({
    OverlayDismissReason reason = OverlayDismissReason.hiddenByApp,
  }) {
    return _hostApi.hideOverlay(
      HideOverlayRequestDto(
        reason: _mapDismissReason(reason),
        requestedAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> updateSettings(OverlaySettings settings) async {
    _lastKnownSettings = settings;
    await _hostApi.updateSettings(_mapSettings(settings));
  }

  @override
  Future<void> refreshDisplays() => _hostApi.refreshDisplays();

  @override
  Future<OverlayStatus> getStatus() async {
    final OverlayStatusDto status = await _hostApi.getOverlayStatus();
    return _mapStatus(status, _lastKnownSettings);
  }

  String _newRequestId() {
    return 'overlay-${DateTime.now().microsecondsSinceEpoch}';
  }
}

class _OverlayFlutterCallbackHandler extends OverlayFlutterApi {
  _OverlayFlutterCallbackHandler({
    required this.emitEvent,
    required this.readSettings,
  });

  final void Function(OverlayEvent event) emitEvent;
  final OverlaySettings Function() readSettings;

  @override
  void onOverlayShown(OverlaySessionDto session) {
    emitEvent(
      OverlayEvent(
        type: OverlayEventType.shown,
        state: OverlayState.visible,
        session: _mapSession(session, readSettings()),
        occurredAt: DateTime.now(),
      ),
    );
  }

  @override
  void onOverlayDismissed(OverlayDismissedDto event) {
    emitEvent(
      OverlayEvent(
        type: OverlayEventType.dismissed,
        state: OverlayState.dismissed,
        dismissReason: _mapDismissReasonFromDto(event.reason),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          event.dismissedAtEpochMillis,
        ),
      ),
    );
  }

  @override
  void onOverlayFailed(OverlayErrorDto error) {
    emitEvent(
      OverlayEvent(
        type: OverlayEventType.failed,
        state: OverlayState.idle,
        dismissReason: OverlayDismissReason.failed,
        message: '${error.code}: ${error.message}',
        occurredAt: DateTime.now(),
      ),
    );
  }

  @override
  void onDisplayTopologyChanged(DisplayTopologyDto topology) {
    emitEvent(
      OverlayEvent(
        type: OverlayEventType.displayTopologyChanged,
        displays: topology.displays.map(_mapDisplay).toList(growable: false),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          topology.changedAtEpochMillis,
        ),
      ),
    );
  }
}

OverlaySettingsDto _mapSettings(OverlaySettings settings) {
  return OverlaySettingsDto(
    intervalMillis: settings.schedule.interval.inMilliseconds,
    durationMillis: settings.duration.value.inMilliseconds,
    interactionMode: _mapInteractionMode(settings.interactionMode),
    fullscreenMode: _mapFullscreenMode(settings.fullscreenMode),
    monitorScope: _mapMonitorScope(settings.monitorScope),
    dismissPolicyType: _mapDismissPolicyType(settings.dismissPolicy.type),
    allowEarlyDismiss: settings.dismissPolicy.allowEarlyDismiss,
  );
}

OverlayStatus _mapStatus(
  OverlayStatusDto status,
  OverlaySettings fallbackSettings,
) {
  return OverlayStatus(
    state: _mapOverlayState(status.state),
    activeSession: status.activeSession == null
        ? null
        : _mapSession(status.activeSession!, fallbackSettings),
    nextTriggerAt: status.nextTriggerAtEpochMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(status.nextTriggerAtEpochMillis!),
  );
}

OverlaySession _mapSession(
  OverlaySessionDto session,
  OverlaySettings settings,
) {
  return OverlaySession(
    id: session.id,
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      session.startedAtEpochMillis,
    ),
    displayTargets: session.displays.map(_mapDisplay).toList(growable: false),
    settings: settings,
  );
}

DisplayTarget _mapDisplay(DisplayTargetDto display) {
  return DisplayTarget(
    id: display.id,
    name: display.name,
    isPrimary: display.isPrimary,
  );
}

InteractionModeDto _mapInteractionMode(InteractionMode value) {
  switch (value) {
    case InteractionMode.blocking:
      return InteractionModeDto.blocking;
    case InteractionMode.passthrough:
      return InteractionModeDto.passthrough;
  }
}

FullscreenModeDto _mapFullscreenMode(FullscreenMode value) {
  switch (value) {
    case FullscreenMode.disabled:
      return FullscreenModeDto.disabled;
    case FullscreenMode.enabled:
      return FullscreenModeDto.enabled;
  }
}

MonitorScopeDto _mapMonitorScope(MonitorScope value) {
  switch (value) {
    case MonitorScope.allDisplays:
      return MonitorScopeDto.allDisplays;
  }
}

DismissPolicyTypeDto _mapDismissPolicyType(DismissPolicyType value) {
  switch (value) {
    case DismissPolicyType.timedOnly:
      return DismissPolicyTypeDto.timedOnly;
    case DismissPolicyType.doubleClickAnywhere:
      return DismissPolicyTypeDto.doubleClickAnywhere;
    case DismissPolicyType.doubleClickCat:
      return DismissPolicyTypeDto.doubleClickCat;
  }
}

OverlayDismissReasonDto _mapDismissReason(OverlayDismissReason value) {
  switch (value) {
    case OverlayDismissReason.timeout:
      return OverlayDismissReasonDto.timeout;
    case OverlayDismissReason.userGesture:
      return OverlayDismissReasonDto.userGesture;
    case OverlayDismissReason.replaced:
      return OverlayDismissReasonDto.replaced;
    case OverlayDismissReason.hiddenByApp:
      return OverlayDismissReasonDto.hiddenByApp;
    case OverlayDismissReason.failed:
      return OverlayDismissReasonDto.failed;
  }
}

OverlayState _mapOverlayState(OverlayStateDto value) {
  switch (value) {
    case OverlayStateDto.idle:
      return OverlayState.idle;
    case OverlayStateDto.scheduled:
      return OverlayState.scheduled;
    case OverlayStateDto.preparing:
      return OverlayState.preparing;
    case OverlayStateDto.visible:
      return OverlayState.visible;
    case OverlayStateDto.dismissed:
      return OverlayState.dismissed;
    case OverlayStateDto.cooldown:
      return OverlayState.cooldown;
    case OverlayStateDto.paused:
      return OverlayState.paused;
  }
}

OverlayDismissReason _mapDismissReasonFromDto(OverlayDismissReasonDto value) {
  switch (value) {
    case OverlayDismissReasonDto.timeout:
      return OverlayDismissReason.timeout;
    case OverlayDismissReasonDto.userGesture:
      return OverlayDismissReason.userGesture;
    case OverlayDismissReasonDto.replaced:
      return OverlayDismissReason.replaced;
    case OverlayDismissReasonDto.hiddenByApp:
      return OverlayDismissReason.hiddenByApp;
    case OverlayDismissReasonDto.failed:
      return OverlayDismissReason.failed;
  }
}

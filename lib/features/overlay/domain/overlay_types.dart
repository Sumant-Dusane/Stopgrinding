enum OverlayState {
  idle,
  scheduled,
  preparing,
  visible,
  dismissed,
  cooldown,
  paused,
}

enum InteractionMode { blocking, passthrough }

enum FullscreenMode { disabled, enabled }

enum MonitorScope { allDisplays }

enum DismissPolicyType { timedOnly, doubleClickAnywhere, doubleClickCat }

enum OverlayDismissReason {
  timeout,
  userGesture,
  replaced,
  hiddenByApp,
  failed,
}

enum OverlayEventType {
  shown,
  dismissed,
  failed,
  displayTopologyChanged,
  stateChanged,
}

enum OverlayResultType {
  shown,
  dismissed,
  failed,
}

class OverlayDuration {
  const OverlayDuration(this.value);

  final Duration value;
}

class OverlaySchedule {
  const OverlaySchedule({
    required this.interval,
    this.startImmediately = false,
  });

  final Duration interval;
  final bool startImmediately;
}

class DismissPolicy {
  const DismissPolicy({required this.type, this.allowEarlyDismiss = false});

  final DismissPolicyType type;
  final bool allowEarlyDismiss;
}

class DisplayTarget {
  const DisplayTarget({
    required this.id,
    required this.name,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final bool isPrimary;
}

class OverlaySettings {
  const OverlaySettings({
    required this.schedule,
    required this.duration,
    required this.interactionMode,
    required this.fullscreenMode,
    required this.monitorScope,
    required this.dismissPolicy,
  });

  factory OverlaySettings.defaults() {
    return OverlaySettings(
      schedule: const OverlaySchedule(interval: Duration(hours: 1)),
      duration: const OverlayDuration(Duration(minutes: 2)),
      interactionMode: InteractionMode.passthrough,
      fullscreenMode: FullscreenMode.disabled,
      monitorScope: MonitorScope.allDisplays,
      dismissPolicy: const DismissPolicy(type: DismissPolicyType.timedOnly),
    );
  }

  final OverlaySchedule schedule;
  final OverlayDuration duration;
  final InteractionMode interactionMode;
  final FullscreenMode fullscreenMode;
  final MonitorScope monitorScope;
  final DismissPolicy dismissPolicy;
}

class OverlaySession {
  const OverlaySession({
    required this.id,
    required this.startedAt,
    required this.displayTargets,
    required this.settings,
  });

  final String id;
  final DateTime startedAt;
  final List<DisplayTarget> displayTargets;
  final OverlaySettings settings;
}

class OverlayStatus {
  const OverlayStatus({
    required this.state,
    this.activeSession,
    this.nextTriggerAt,
  });

  final OverlayState state;
  final OverlaySession? activeSession;
  final DateTime? nextTriggerAt;
}

class OverlayEvent {
  const OverlayEvent({
    required this.type,
    this.state,
    this.session,
    this.dismissReason,
    this.displays = const <DisplayTarget>[],
    this.message,
    this.occurredAt,
  });

  final OverlayEventType type;
  final OverlayState? state;
  final OverlaySession? session;
  final OverlayDismissReason? dismissReason;
  final List<DisplayTarget> displays;
  final String? message;
  final DateTime? occurredAt;
}

class OverlayResult {
  const OverlayResult({
    required this.type,
    required this.occurredAt,
    this.dismissReason,
    this.message,
    this.sessionId,
  });

  final OverlayResultType type;
  final DateTime occurredAt;
  final OverlayDismissReason? dismissReason;
  final String? message;
  final String? sessionId;
}

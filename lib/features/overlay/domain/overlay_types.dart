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

enum OverlayResultType { shown, dismissed, failed }

class OverlayCatalogItem {
  const OverlayCatalogItem({
    required this.id,
    required this.title,
    required this.assetPath,
    this.loopStart = Duration.zero,
    this.loopEnd,
  });

  final String id;
  final String title;
  final String assetPath;
  final Duration loopStart;
  final Duration? loopEnd;
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
    required this.selectedOverlayId,
    required this.selectedOverlayAssetPath,
    required this.selectedOverlayLoopStart,
    required this.selectedOverlayLoopEnd,
  });

  factory OverlaySettings.defaults() {
    return OverlaySettings(
      schedule: const OverlaySchedule(interval: Duration(hours: 1)),
      duration: const OverlayDuration(Duration(minutes: 2)),
      interactionMode: InteractionMode.passthrough,
      fullscreenMode: FullscreenMode.disabled,
      monitorScope: MonitorScope.allDisplays,
      dismissPolicy: const DismissPolicy(type: DismissPolicyType.timedOnly),
      selectedOverlayId: '',
      selectedOverlayAssetPath: '',
      selectedOverlayLoopStart: Duration.zero,
      selectedOverlayLoopEnd: null,
    );
  }

  final OverlaySchedule schedule;
  final OverlayDuration duration;
  final InteractionMode interactionMode;
  final FullscreenMode fullscreenMode;
  final MonitorScope monitorScope;
  final DismissPolicy dismissPolicy;
  final String selectedOverlayId;
  final String selectedOverlayAssetPath;
  final Duration selectedOverlayLoopStart;
  final Duration? selectedOverlayLoopEnd;

  OverlaySettings copyWith({
    OverlaySchedule? schedule,
    OverlayDuration? duration,
    InteractionMode? interactionMode,
    FullscreenMode? fullscreenMode,
    MonitorScope? monitorScope,
    DismissPolicy? dismissPolicy,
    String? selectedOverlayId,
    String? selectedOverlayAssetPath,
    Duration? selectedOverlayLoopStart,
    Object? selectedOverlayLoopEnd = _overlayLoopSentinel,
  }) {
    return OverlaySettings(
      schedule: schedule ?? this.schedule,
      duration: duration ?? this.duration,
      interactionMode: interactionMode ?? this.interactionMode,
      fullscreenMode: fullscreenMode ?? this.fullscreenMode,
      monitorScope: monitorScope ?? this.monitorScope,
      dismissPolicy: dismissPolicy ?? this.dismissPolicy,
      selectedOverlayId: selectedOverlayId ?? this.selectedOverlayId,
      selectedOverlayAssetPath:
          selectedOverlayAssetPath ?? this.selectedOverlayAssetPath,
      selectedOverlayLoopStart:
          selectedOverlayLoopStart ?? this.selectedOverlayLoopStart,
      selectedOverlayLoopEnd:
          identical(selectedOverlayLoopEnd, _overlayLoopSentinel)
          ? this.selectedOverlayLoopEnd
          : selectedOverlayLoopEnd as Duration?,
    );
  }

  OverlaySettings normalized([
    List<OverlayCatalogItem> catalog = const <OverlayCatalogItem>[],
  ]) {
    final bool shouldDisableEarlyDismiss =
        dismissPolicy.type == DismissPolicyType.timedOnly ||
        interactionMode == InteractionMode.passthrough;
    final OverlayCatalogItem? resolvedOverlay = _resolveCatalogItem(
      selectedOverlayId: selectedOverlayId,
      selectedOverlayAssetPath: selectedOverlayAssetPath,
      catalog: catalog,
    );

    return copyWith(
      dismissPolicy: shouldDisableEarlyDismiss
          ? DismissPolicy(type: dismissPolicy.type, allowEarlyDismiss: false)
          : dismissPolicy,
      selectedOverlayId: resolvedOverlay?.id ?? selectedOverlayId,
      selectedOverlayAssetPath:
          resolvedOverlay?.assetPath ?? selectedOverlayAssetPath,
      selectedOverlayLoopStart:
          resolvedOverlay?.loopStart ?? selectedOverlayLoopStart,
      selectedOverlayLoopEnd:
          resolvedOverlay?.loopEnd ?? selectedOverlayLoopEnd,
    );
  }

  OverlayCatalogItem selectedCatalogItem(List<OverlayCatalogItem> catalog) {
    final OverlayCatalogItem? item = _resolveCatalogItem(
      selectedOverlayId: selectedOverlayId,
      selectedOverlayAssetPath: selectedOverlayAssetPath,
      catalog: catalog,
    );
    if (item != null) {
      return item;
    }
    throw StateError('No overlay catalog items are available.');
  }

  bool hasSameValues(OverlaySettings other) {
    return schedule.interval == other.schedule.interval &&
        schedule.startImmediately == other.schedule.startImmediately &&
        duration.value == other.duration.value &&
        interactionMode == other.interactionMode &&
        fullscreenMode == other.fullscreenMode &&
        monitorScope == other.monitorScope &&
        dismissPolicy.type == other.dismissPolicy.type &&
        dismissPolicy.allowEarlyDismiss ==
            other.dismissPolicy.allowEarlyDismiss &&
        selectedOverlayId == other.selectedOverlayId &&
        selectedOverlayAssetPath == other.selectedOverlayAssetPath &&
        selectedOverlayLoopStart == other.selectedOverlayLoopStart &&
        selectedOverlayLoopEnd == other.selectedOverlayLoopEnd;
  }
}

const Object _overlayLoopSentinel = Object();

OverlayCatalogItem? _resolveCatalogItem({
  required String selectedOverlayId,
  required String selectedOverlayAssetPath,
  required List<OverlayCatalogItem> catalog,
}) {
  for (final OverlayCatalogItem item in catalog) {
    if (item.id == selectedOverlayId) {
      return item;
    }
  }

  for (final OverlayCatalogItem item in catalog) {
    if (item.assetPath == selectedOverlayAssetPath) {
      return item;
    }
  }

  if (catalog.isNotEmpty) {
    return catalog.first;
  }

  return null;
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

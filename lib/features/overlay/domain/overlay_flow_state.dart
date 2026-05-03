import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

class OverlayFlowState {
  const OverlayFlowState({
    required this.lifecycle,
    required this.settings,
    this.activeSession,
    this.nextTriggerAt,
    this.displays = const <DisplayTarget>[],
    this.lastDismissReason,
    this.lastError,
    this.lastUpdatedAt,
    this.isInitialized = false,
  });

  factory OverlayFlowState.initial() {
    return OverlayFlowState(
      lifecycle: OverlayState.idle,
      settings: OverlaySettings.defaults(),
      lastUpdatedAt: DateTime.now(),
    );
  }

  final OverlayState lifecycle;
  final OverlaySettings settings;
  final OverlaySession? activeSession;
  final DateTime? nextTriggerAt;
  final List<DisplayTarget> displays;
  final OverlayDismissReason? lastDismissReason;
  final String? lastError;
  final DateTime? lastUpdatedAt;
  final bool isInitialized;

  bool get isOverlayActive =>
      lifecycle == OverlayState.preparing || lifecycle == OverlayState.visible;

  OverlayFlowState copyWith({
    OverlayState? lifecycle,
    OverlaySettings? settings,
    Object? activeSession = _sentinel,
    Object? nextTriggerAt = _sentinel,
    List<DisplayTarget>? displays,
    Object? lastDismissReason = _sentinel,
    Object? lastError = _sentinel,
    DateTime? lastUpdatedAt,
    bool? isInitialized,
  }) {
    return OverlayFlowState(
      lifecycle: lifecycle ?? this.lifecycle,
      settings: settings ?? this.settings,
      activeSession: identical(activeSession, _sentinel)
          ? this.activeSession
          : activeSession as OverlaySession?,
      nextTriggerAt: identical(nextTriggerAt, _sentinel)
          ? this.nextTriggerAt
          : nextTriggerAt as DateTime?,
      displays: displays ?? this.displays,
      lastDismissReason: identical(lastDismissReason, _sentinel)
          ? this.lastDismissReason
          : lastDismissReason as OverlayDismissReason?,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

const Object _sentinel = Object();

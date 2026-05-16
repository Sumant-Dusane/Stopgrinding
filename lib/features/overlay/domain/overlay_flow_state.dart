import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

class OverlayFlowState {
  const OverlayFlowState({
    required this.lifecycle,
    required this.settings,
    this.catalog = const <OverlayCatalogItem>[],
    this.activeSession,
    this.visibleUntil,
    this.nextTriggerAt,
    this.displays = const <DisplayTarget>[],
    this.lastResult,
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
  final List<OverlayCatalogItem> catalog;
  final OverlaySession? activeSession;
  final DateTime? visibleUntil;
  final DateTime? nextTriggerAt;
  final List<DisplayTarget> displays;
  final OverlayResult? lastResult;
  final OverlayDismissReason? lastDismissReason;
  final String? lastError;
  final DateTime? lastUpdatedAt;
  final bool isInitialized;

  bool get isOverlayActive =>
      lifecycle == OverlayState.preparing || lifecycle == OverlayState.visible;

  OverlayFlowState copyWith({
    OverlayState? lifecycle,
    OverlaySettings? settings,
    List<OverlayCatalogItem>? catalog,
    Object? activeSession = _sentinel,
    Object? visibleUntil = _sentinel,
    Object? nextTriggerAt = _sentinel,
    List<DisplayTarget>? displays,
    Object? lastResult = _sentinel,
    Object? lastDismissReason = _sentinel,
    Object? lastError = _sentinel,
    DateTime? lastUpdatedAt,
    bool? isInitialized,
  }) {
    return OverlayFlowState(
      lifecycle: lifecycle ?? this.lifecycle,
      settings: settings ?? this.settings,
      catalog: catalog ?? this.catalog,
      activeSession: identical(activeSession, _sentinel)
          ? this.activeSession
          : activeSession as OverlaySession?,
      visibleUntil: identical(visibleUntil, _sentinel)
          ? this.visibleUntil
          : visibleUntil as DateTime?,
      nextTriggerAt: identical(nextTriggerAt, _sentinel)
          ? this.nextTriggerAt
          : nextTriggerAt as DateTime?,
      displays: displays ?? this.displays,
      lastResult: identical(lastResult, _sentinel)
          ? this.lastResult
          : lastResult as OverlayResult?,
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

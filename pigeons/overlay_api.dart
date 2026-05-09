import 'package:pigeon/pigeon.dart';

enum InteractionModeDto { blocking, passthrough }

enum FullscreenModeDto { disabled, enabled }

enum MonitorScopeDto { allDisplays }

enum DismissPolicyTypeDto { timedOnly, doubleClickAnywhere, doubleClickCat }

enum OverlayStateDto {
  idle,
  scheduled,
  preparing,
  visible,
  dismissed,
  cooldown,
  paused,
}

enum OverlayDismissReasonDto {
  timeout,
  userGesture,
  replaced,
  hiddenByApp,
  failed,
}

class OverlaySettingsDto {
  OverlaySettingsDto({
    required this.intervalMillis,
    required this.durationMillis,
    required this.interactionMode,
    required this.fullscreenMode,
    required this.monitorScope,
    required this.dismissPolicyType,
    required this.allowEarlyDismiss,
    required this.selectedOverlayId,
    required this.selectedOverlayAssetPath,
  });

  final int intervalMillis;
  final int durationMillis;
  final InteractionModeDto interactionMode;
  final FullscreenModeDto fullscreenMode;
  final MonitorScopeDto monitorScope;
  final DismissPolicyTypeDto dismissPolicyType;
  final bool allowEarlyDismiss;
  final String selectedOverlayId;
  final String selectedOverlayAssetPath;
}

class OverlayCatalogItemDto {
  OverlayCatalogItemDto({
    required this.id,
    required this.title,
    required this.assetPath,
  });

  final String id;
  final String title;
  final String assetPath;
}

class OverlayRequestDto {
  OverlayRequestDto({
    required this.requestId,
    required this.settings,
    this.triggeredAtEpochMillis,
  });

  final String requestId;
  final OverlaySettingsDto settings;
  final int? triggeredAtEpochMillis;
}

class HideOverlayRequestDto {
  HideOverlayRequestDto({required this.reason, this.requestedAtEpochMillis});

  final OverlayDismissReasonDto reason;
  final int? requestedAtEpochMillis;
}

class DisplayTargetDto {
  DisplayTargetDto({
    required this.id,
    required this.name,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final bool isPrimary;
}

class OverlaySessionDto {
  OverlaySessionDto({
    required this.id,
    required this.startedAtEpochMillis,
    required this.displays,
  });

  final String id;
  final int startedAtEpochMillis;
  final List<DisplayTargetDto> displays;
}

class OverlayDismissedDto {
  OverlayDismissedDto({
    required this.sessionId,
    required this.reason,
    required this.dismissedAtEpochMillis,
  });

  final String sessionId;
  final OverlayDismissReasonDto reason;
  final int dismissedAtEpochMillis;
}

class OverlayErrorDto {
  OverlayErrorDto({required this.code, required this.message});

  final String code;
  final String message;
}

class DisplayTopologyDto {
  DisplayTopologyDto({
    required this.displays,
    required this.changedAtEpochMillis,
  });

  final List<DisplayTargetDto> displays;
  final int changedAtEpochMillis;
}

class OverlayStatusDto {
  OverlayStatusDto({
    required this.state,
    this.activeSession,
    this.nextTriggerAtEpochMillis,
  });

  final OverlayStateDto state;
  final OverlaySessionDto? activeSession;
  final int? nextTriggerAtEpochMillis;
}

@HostApi()
abstract class OverlayHostApi {
  void initialize();

  void showOverlay(OverlayRequestDto request);

  void hideOverlay(HideOverlayRequestDto request);

  void updateSettings(OverlaySettingsDto settings);

  List<OverlayCatalogItemDto> getOverlayCatalog();

  void refreshDisplays();

  OverlayStatusDto getOverlayStatus();
}

@FlutterApi()
abstract class OverlayFlutterApi {
  void onOverlayShown(OverlaySessionDto session);

  void onOverlayDismissed(OverlayDismissedDto event);

  void onOverlayFailed(OverlayErrorDto error);

  void onDisplayTopologyChanged(DisplayTopologyDto topology);
}

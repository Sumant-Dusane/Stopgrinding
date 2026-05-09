import 'package:shared_preferences/shared_preferences.dart';

import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/settings/domain/overlay_settings_repository.dart';

class SharedPreferencesOverlaySettingsRepository
    implements OverlaySettingsRepository {
  SharedPreferencesOverlaySettingsRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _intervalMinutesKey = 'overlay.interval_minutes';
  static const String _durationMinutesKey = 'overlay.duration_minutes';
  static const String _interactionModeKey = 'overlay.interaction_mode';
  static const String _fullscreenModeKey = 'overlay.fullscreen_mode';
  static const String _dismissPolicyTypeKey = 'overlay.dismiss_policy_type';
  static const String _allowEarlyDismissKey = 'overlay.allow_early_dismiss';
  static const String _selectedOverlayIdKey = 'overlay.selected_overlay_id';
  static const String _selectedOverlayAssetPathKey =
      'overlay.selected_overlay_asset_path';

  final SharedPreferencesAsync _preferences;

  @override
  Future<OverlaySettings> load() async {
    final OverlaySettings defaults = OverlaySettings.defaults();

    final int intervalMinutes =
        await _preferences.getInt(_intervalMinutesKey) ??
        defaults.schedule.interval.inMinutes;
    final int durationMinutes =
        await _preferences.getInt(_durationMinutesKey) ??
        defaults.duration.value.inMinutes;
    final InteractionMode interactionMode = _interactionModeFromName(
      await _preferences.getString(_interactionModeKey),
      defaults.interactionMode,
    );
    final FullscreenMode fullscreenMode = _fullscreenModeFromName(
      await _preferences.getString(_fullscreenModeKey),
      defaults.fullscreenMode,
    );
    final DismissPolicyType dismissPolicyType = _dismissPolicyTypeFromName(
      await _preferences.getString(_dismissPolicyTypeKey),
      defaults.dismissPolicy.type,
    );
    final bool allowEarlyDismiss =
        await _preferences.getBool(_allowEarlyDismissKey) ??
        defaults.dismissPolicy.allowEarlyDismiss;
    final String selectedOverlayId =
        await _preferences.getString(_selectedOverlayIdKey) ??
        defaults.selectedOverlayId;
    final String selectedOverlayAssetPath =
        await _preferences.getString(_selectedOverlayAssetPathKey) ??
        defaults.selectedOverlayAssetPath;

    return OverlaySettings(
      schedule: OverlaySchedule(interval: Duration(minutes: intervalMinutes)),
      duration: OverlayDuration(Duration(minutes: durationMinutes)),
      interactionMode: interactionMode,
      fullscreenMode: fullscreenMode,
      monitorScope: MonitorScope.allDisplays,
      dismissPolicy: DismissPolicy(
        type: dismissPolicyType,
        allowEarlyDismiss: dismissPolicyType == DismissPolicyType.timedOnly
            ? false
            : allowEarlyDismiss,
      ),
      selectedOverlayId: selectedOverlayId,
      selectedOverlayAssetPath: selectedOverlayAssetPath,
      selectedOverlayLoopStart: defaults.selectedOverlayLoopStart,
      selectedOverlayLoopEnd: defaults.selectedOverlayLoopEnd,
    ).normalized();
  }

  @override
  Future<void> save(OverlaySettings settings) async {
    await _preferences.setInt(
      _intervalMinutesKey,
      settings.schedule.interval.inMinutes,
    );
    await _preferences.setInt(
      _durationMinutesKey,
      settings.duration.value.inMinutes,
    );
    await _preferences.setString(
      _interactionModeKey,
      settings.interactionMode.name,
    );
    await _preferences.setString(
      _fullscreenModeKey,
      settings.fullscreenMode.name,
    );
    await _preferences.setString(
      _dismissPolicyTypeKey,
      settings.dismissPolicy.type.name,
    );
    await _preferences.setBool(
      _allowEarlyDismissKey,
      settings.dismissPolicy.allowEarlyDismiss,
    );
    await _preferences.setString(
      _selectedOverlayIdKey,
      settings.selectedOverlayId,
    );
    await _preferences.setString(
      _selectedOverlayAssetPathKey,
      settings.selectedOverlayAssetPath,
    );
  }
}

InteractionMode _interactionModeFromName(
  String? value,
  InteractionMode fallback,
) {
  for (final InteractionMode mode in InteractionMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  return fallback;
}

FullscreenMode _fullscreenModeFromName(String? value, FullscreenMode fallback) {
  for (final FullscreenMode mode in FullscreenMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  return fallback;
}

DismissPolicyType _dismissPolicyTypeFromName(
  String? value,
  DismissPolicyType fallback,
) {
  for (final DismissPolicyType policy in DismissPolicyType.values) {
    if (policy.name == value) {
      return policy;
    }
  }
  return fallback;
}

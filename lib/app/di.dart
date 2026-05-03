import 'package:stopgrinding/features/overlay/domain/dismiss_overlay.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/show_overlay.dart';
import 'package:stopgrinding/features/scheduler/domain/scheduler_service.dart';
import 'package:stopgrinding/features/scheduler/domain/timer_break_scheduler.dart';
import 'package:stopgrinding/features/settings/domain/save_settings.dart';
import 'package:stopgrinding/features/settings/infrastructure/launch_at_startup_service.dart';
import 'package:stopgrinding/features/settings/infrastructure/shared_preferences_overlay_settings_repository.dart';
import 'package:stopgrinding/platform/bridge/pigeon_overlay_bridge.dart';

class AppDi {
  AppDi({
    required this.overlayService,
    required this.launchAtStartupService,
    required this.showOverlay,
    required this.dismissOverlay,
    required this.saveSettings,
  });

  factory AppDi.bootstrap() {
    final overlayBridge = PigeonOverlayBridge();
    final schedulerService = SchedulerService(scheduler: TimerBreakScheduler());
    final launchAtStartupService = LaunchAtStartupService();
    final overlayService = OverlayService(
      controller: overlayBridge,
      schedulerService: schedulerService,
      settingsRepository: SharedPreferencesOverlaySettingsRepository(),
    );

    return AppDi(
      overlayService: overlayService,
      launchAtStartupService: launchAtStartupService,
      showOverlay: ShowOverlay(overlayService),
      dismissOverlay: DismissOverlay(overlayService),
      saveSettings: SaveSettings(overlayService),
    );
  }

  final OverlayService overlayService;
  final LaunchAtStartupService launchAtStartupService;
  final ShowOverlay showOverlay;
  final DismissOverlay dismissOverlay;
  final SaveSettings saveSettings;
}

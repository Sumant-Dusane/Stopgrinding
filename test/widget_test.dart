import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stopgrinding/app/app.dart';
import 'package:stopgrinding/app/di.dart';
import 'package:stopgrinding/features/overlay/domain/dismiss_overlay.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_controller.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart'
    as domain;
import 'package:stopgrinding/features/overlay/domain/show_overlay.dart';
import 'package:stopgrinding/features/scheduler/domain/break_scheduler.dart';
import 'package:stopgrinding/features/scheduler/domain/scheduler_service.dart';
import 'package:stopgrinding/features/settings/domain/in_memory_overlay_settings_repository.dart';
import 'package:stopgrinding/features/settings/domain/save_settings.dart';
import 'package:stopgrinding/features/settings/infrastructure/launch_at_startup_service.dart';

void main() {
  testWidgets('boots the phase 4 overlay shell', (WidgetTester tester) async {
    final _FakeOverlayController controller = _FakeOverlayController();
    final _FakeBreakScheduler scheduler = _FakeBreakScheduler();
    final OverlayService overlayService = OverlayService(
      controller: controller,
      schedulerService: SchedulerService(scheduler: scheduler),
      settingsRepository: InMemoryOverlaySettingsRepository(),
    );
    final AppDi di = AppDi(
      overlayService: overlayService,
      launchAtStartupService: LaunchAtStartupService(
        adapter: _FakeLaunchAtStartupAdapter(),
      ),
      showOverlay: ShowOverlay(overlayService),
      dismissOverlay: DismissOverlay(overlayService),
      saveSettings: SaveSettings(overlayService),
    );

    await tester.pumpWidget(StopGrindingApp(di: di));
    await tester.pump();

    expect(find.text('StopGrinding'), findsOneWidget);
    expect(find.textContaining('Lifecycle:'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Manual trigger'), findsOneWidget);
    expect(find.text('Startup'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Break media'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save settings'), findsOneWidget);
  });
}

class _FakeLaunchAtStartupAdapter implements LaunchAtStartupAdapter {
  bool enabled = false;

  @override
  Future<void> disable() async {
    enabled = false;
  }

  @override
  Future<void> enable() async {
    enabled = true;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isEnabled() async => enabled;
}

class _FakeOverlayController implements OverlayController {
  final StreamController<domain.OverlayEvent> _eventsController =
      StreamController<domain.OverlayEvent>.broadcast();

  final domain.OverlayStatus _status = domain.OverlayStatus(
    state: domain.OverlayState.idle,
  );

  @override
  Stream<domain.OverlayEvent> get events => _eventsController.stream;

  @override
  Future<domain.OverlayStatus> getStatus() async => _status;

  @override
  Future<List<domain.OverlayCatalogItem>> getOverlayCatalog() async =>
      const <domain.OverlayCatalogItem>[
        domain.OverlayCatalogItem(
          id: 'neko-cat',
          title: 'Neko Cat',
          assetPath: 'assets/overlays/neko_cat/animation.mov',
        ),
      ];

  @override
  Future<void> hideOverlay({
    domain.OverlayDismissReason reason =
        domain.OverlayDismissReason.hiddenByApp,
  }) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshDisplays() async {}

  @override
  Future<void> showOverlay(domain.OverlaySettings settings) async {}

  @override
  Future<void> updateSettings(domain.OverlaySettings settings) async {}
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
  Future<void> start(domain.OverlaySchedule schedule) async {
    nextTriggerAt = DateTime(2026, 1, 1, 10);
  }

  @override
  Future<void> stop() async {
    nextTriggerAt = null;
  }
}

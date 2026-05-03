import 'package:flutter/material.dart';

import 'package:stopgrinding/app/di.dart';
import 'package:stopgrinding/features/overlay/presentation/overlay_home_screen.dart';

abstract final class AppRoute {
  static const home = '/';
}

Map<String, WidgetBuilder> appRoutes(AppDi di) {
  return {
    AppRoute.home: (_) => OverlayHomeScreen(
      overlayService: di.overlayService,
      launchAtStartupService: di.launchAtStartupService,
      showOverlay: di.showOverlay,
      dismissOverlay: di.dismissOverlay,
      saveSettings: di.saveSettings,
    ),
  };
}

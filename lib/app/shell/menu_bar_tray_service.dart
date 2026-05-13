import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import 'package:stopgrinding/app/shell/menu_bar_tray_config.dart';
import 'package:stopgrinding/app/shell/shell_navigation_controller.dart';
import 'package:stopgrinding/app/shell/shell_window_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/overlay/domain/show_overlay.dart';

class MenuBarTrayService with TrayListener {
  MenuBarTrayService({
    required this.overlayService,
    required this.showOverlay,
    required this.shellNavigationController,
    required this.shellWindowService,
  });

  final OverlayService overlayService;
  final ShowOverlay showOverlay;
  final ShellNavigationController shellNavigationController;
  final ShellWindowService shellWindowService;

  bool _isInitialized = false;
  VoidCallback? _overlayStateListener;

  Future<void> initialize() async {
    if (_isInitialized || defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    trayManager.addListener(this);
    await trayManager.setIcon(
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png',
      iconPosition: TrayIconPosition.left,
    );
    await trayManager.setToolTip('StopGrinding');
    await _rebuildMenu();

    _overlayStateListener = () {
      _rebuildMenu();
    };
    overlayService.addListener(_overlayStateListener!);
    _isInitialized = true;
  }

  Future<void> disposeService() async {
    if (!_isInitialized) {
      return;
    }

    if (_overlayStateListener != null) {
      overlayService.removeListener(_overlayStateListener!);
      _overlayStateListener = null;
    }
    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final MenuBarTrayAction? action = _parseAction(menuItem.key);
    if (action == null) {
      return;
    }

    unawaited(_handleAction(action));
  }

  Future<void> _handleAction(MenuBarTrayAction action) async {
    switch (action) {
      case MenuBarTrayAction.openDashboard:
        shellNavigationController.openHome();
        await shellWindowService.showMainWindow();
      case MenuBarTrayAction.openSettings:
        shellNavigationController.openSettings();
        await shellWindowService.showMainWindow();
      case MenuBarTrayAction.triggerBreakNow:
        await shellWindowService.showMainWindow();
        await showOverlay();
      case MenuBarTrayAction.toggleScheduler:
        if (overlayService.state.lifecycle == OverlayState.paused) {
          await overlayService.resume();
        } else {
          await overlayService.pause();
        }
      case MenuBarTrayAction.quitApp:
        await shellWindowService.quitApp();
    }
  }

  Future<void> _rebuildMenu() async {
    final OverlayState lifecycle = overlayService.state.lifecycle;
    final Menu menu = Menu(
      items: kMenuBarTrayItems
          .map((spec) {
            if (spec.kind == MenuBarTrayItemKind.separator) {
              return MenuItem.separator();
            }

            final MenuBarTrayAction action = spec.action!;
            return MenuItem(
              key: action.name,
              label: resolveMenuBarTrayLabel(action, lifecycle),
            );
          })
          .toList(growable: false),
    );
    await trayManager.setContextMenu(menu);
  }

  MenuBarTrayAction? _parseAction(String? key) {
    if (key == null) {
      return null;
    }
    for (final MenuBarTrayAction action in MenuBarTrayAction.values) {
      if (action.name == key) {
        return action;
      }
    }
    return null;
  }
}

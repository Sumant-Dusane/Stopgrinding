import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

enum MenuBarTrayAction {
  openDashboard,
  openSettings,
  triggerBreakNow,
  toggleScheduler,
  quitApp,
}

enum MenuBarTrayItemKind { action, separator }

class MenuBarTrayItemSpec {
  const MenuBarTrayItemSpec._({required this.kind, this.action, this.label});

  const MenuBarTrayItemSpec.action({
    required MenuBarTrayAction action,
    required String label,
  }) : this._(kind: MenuBarTrayItemKind.action, action: action, label: label);

  const MenuBarTrayItemSpec.separator()
    : this._(kind: MenuBarTrayItemKind.separator);

  final MenuBarTrayItemKind kind;
  final MenuBarTrayAction? action;
  final String? label;
}

const List<MenuBarTrayItemSpec> kMenuBarTrayItems = <MenuBarTrayItemSpec>[
  MenuBarTrayItemSpec.action(
    action: MenuBarTrayAction.openDashboard,
    label: 'Open StopGrinding',
  ),
  MenuBarTrayItemSpec.action(
    action: MenuBarTrayAction.openSettings,
    label: 'Open Settings',
  ),
  MenuBarTrayItemSpec.separator(),
  MenuBarTrayItemSpec.action(
    action: MenuBarTrayAction.triggerBreakNow,
    label: 'Run Break Now',
  ),
  MenuBarTrayItemSpec.action(
    action: MenuBarTrayAction.toggleScheduler,
    label: 'Toggle Scheduler',
  ),
  MenuBarTrayItemSpec.separator(),
  MenuBarTrayItemSpec.action(
    action: MenuBarTrayAction.quitApp,
    label: 'Quit StopGrinding',
  ),
];

String resolveMenuBarTrayLabel(
  MenuBarTrayAction action,
  OverlayState lifecycle,
) {
  switch (action) {
    case MenuBarTrayAction.openDashboard:
      return 'Open StopGrinding';
    case MenuBarTrayAction.openSettings:
      return 'Open Settings';
    case MenuBarTrayAction.triggerBreakNow:
      return 'Run Break Now';
    case MenuBarTrayAction.toggleScheduler:
      return lifecycle == OverlayState.paused
          ? 'Resume Scheduler'
          : 'Pause Scheduler';
    case MenuBarTrayAction.quitApp:
      return 'Quit StopGrinding';
  }
}

import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';

enum MenuBarTrayAction {
  openDashboard,
  openSettings,
  triggerBreakNow,
  toggleScheduler,
  quitApp,
}

const String kBreakCountdownMenuKey = 'break-countdown';

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

String formatTrayCountdown(Duration remaining) {
  final Duration clamped = remaining.isNegative ? Duration.zero : remaining;
  final int hours = clamped.inHours;
  final int minutes = clamped.inMinutes.remainder(60);
  final int seconds = clamped.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String resolveTrayTitle(Duration remaining) {
  return formatTrayCountdown(remaining);
}

String resolveTrayToolTip(Duration? remaining) {
  if (remaining == null) {
    return 'StopGrinding';
  }
  return 'StopGrinding • Break ends in ${formatTrayCountdown(remaining)}';
}

String resolveBreakCountdownLabel(Duration remaining) {
  return 'Break ends in ${formatTrayCountdown(remaining)}';
}

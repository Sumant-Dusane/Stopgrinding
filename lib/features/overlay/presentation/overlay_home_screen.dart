import 'package:flutter/material.dart' hide OverlayState;

import 'package:stopgrinding/features/overlay/domain/dismiss_overlay.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_flow_state.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/overlay/domain/show_overlay.dart';
import 'package:stopgrinding/features/settings/domain/save_settings.dart';
import 'package:stopgrinding/features/settings/infrastructure/launch_at_startup_service.dart';

class OverlayHomeScreen extends StatefulWidget {
  const OverlayHomeScreen({
    super.key,
    required this.overlayService,
    required this.launchAtStartupService,
    required this.showOverlay,
    required this.dismissOverlay,
    required this.saveSettings,
  });

  final OverlayService overlayService;
  final LaunchAtStartupService launchAtStartupService;
  final ShowOverlay showOverlay;
  final DismissOverlay dismissOverlay;
  final SaveSettings saveSettings;

  @override
  State<OverlayHomeScreen> createState() => _OverlayHomeScreenState();
}

class _OverlayHomeScreenState extends State<OverlayHomeScreen> {
  OverlaySettings? _draftSettings;
  OverlaySettings? _lastSyncedSettings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    widget.overlayService.initialize();
    widget.launchAtStartupService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StopGrinding')),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          widget.overlayService,
          widget.launchAtStartupService,
        ]),
        builder: (context, _) {
          final OverlayFlowState state = widget.overlayService.state;
          final LaunchAtStartupService startup = widget.launchAtStartupService;
          _syncDraftIfNeeded(state.settings);
          final OverlaySettings settings = _draftSettings ?? state.settings;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DebugPanel(state: state, startup: startup),
                const SizedBox(height: 24),
                _ActionsRow(
                  state: state,
                  onShowOverlay: () {
                    widget.showOverlay();
                  },
                  onDismissOverlay: () {
                    widget.dismissOverlay(
                      reason: OverlayDismissReason.hiddenByApp,
                    );
                  },
                  onRefreshDisplays: widget.overlayService.refreshDisplays,
                  onRecover: widget.overlayService.recover,
                  onPause: widget.overlayService.pause,
                  onResume: widget.overlayService.resume,
                ),
                const SizedBox(height: 24),
                _StartupPanel(
                  startup: startup,
                  onChanged: (enabled) {
                    widget.launchAtStartupService.setEnabled(enabled);
                  },
                ),
                const SizedBox(height: 24),
                _SettingsPanel(
                  settings: settings,
                  isSaving: _isSaving,
                  onIntervalChanged: (minutes) {
                    _updateDraft(
                      settings.copyWithSchedule(
                        OverlaySchedule(
                          interval: Duration(minutes: minutes),
                          startImmediately:
                              settings.schedule.startImmediately,
                        ),
                      ),
                    );
                  },
                  onDurationChanged: (minutes) {
                    _updateDraft(
                      settings.copyWithDuration(
                        OverlayDuration(Duration(minutes: minutes)),
                      ),
                    );
                  },
                  onInteractionModeChanged: (value) {
                    _updateDraft(
                      settings.copyWithInteractionMode(value).normalized(),
                    );
                  },
                  onFullscreenModeChanged: (value) {
                    _updateDraft(settings.copyWithFullscreenMode(value));
                  },
                  onDismissPolicyTypeChanged: (value) {
                    _updateDraft(
                      settings.copyWithDismissPolicy(
                        DismissPolicy(
                          type: value,
                          allowEarlyDismiss:
                              value == DismissPolicyType.timedOnly
                                  ? false
                                  : settings.dismissPolicy.allowEarlyDismiss,
                        ),
                      ),
                    );
                  },
                  onAllowEarlyDismissChanged: (value) {
                    _updateDraft(
                      settings.copyWithDismissPolicy(
                        DismissPolicy(
                          type: settings.dismissPolicy.type,
                          allowEarlyDismiss: value,
                        ),
                      ).normalized(),
                    );
                  },
                  onSave: () => _saveSettings(settings),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _syncDraftIfNeeded(OverlaySettings source) {
    if (_lastSyncedSettings == null ||
        !_lastSyncedSettings!.hasSameValues(source) ||
        _draftSettings == null) {
      _draftSettings = source;
      _lastSyncedSettings = source;
    }
  }

  void _updateDraft(OverlaySettings nextSettings) {
    setState(() {
      _draftSettings = nextSettings;
    });
  }

  Future<void> _saveSettings(OverlaySettings settings) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.saveSettings(settings.normalized());
      if (!mounted) {
        return;
      }

      final bool saveSucceeded =
          widget.overlayService.state.settings.hasSameValues(
            settings.normalized(),
          ) &&
          widget.overlayService.state.lastError == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveSucceeded ? 'Settings saved' : 'Settings update failed',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.state, required this.startup});

  final OverlayFlowState state;
  final LaunchAtStartupService startup;

  @override
  Widget build(BuildContext context) {
    final OverlaySettings settings = state.settings;
    final OverlayResult? result = state.lastResult;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text('Lifecycle: ${state.lifecycle.name}'),
            const SizedBox(height: 8),
            Text(
              'Next trigger: ${_formatDateTime(state.nextTriggerAt) ?? 'unscheduled'}',
            ),
            const SizedBox(height: 8),
            Text(
              'Current cadence: ${settings.duration.value.inMinutes}m every ${settings.schedule.interval.inMinutes}m',
            ),
            const SizedBox(height: 8),
            Text(
              'Last overlay result: ${_resultSummary(result) ?? 'No completed session yet'}',
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text('Last result time: ${_formatDateTime(result.occurredAt)}'),
            ],
            const SizedBox(height: 8),
            Text('Displays: ${state.displays.length}'),
            const SizedBox(height: 8),
            Text(
              'Launch at login: ${startup.isInitialized ? (startup.isEnabled ? 'enabled' : 'disabled') : 'loading'}',
            ),
            if (state.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last overlay error: ${state.lastError}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (startup.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Launch-at-login error: ${startup.lastError}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.state,
    required this.onShowOverlay,
    required this.onDismissOverlay,
    required this.onRefreshDisplays,
    required this.onRecover,
    required this.onPause,
    required this.onResume,
  });

  final OverlayFlowState state;
  final VoidCallback onShowOverlay;
  final VoidCallback onDismissOverlay;
  final Future<void> Function() onRefreshDisplays;
  final Future<void> Function() onRecover;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton(
          onPressed: onShowOverlay,
          child: const Text('Manual trigger'),
        ),
        OutlinedButton(
          onPressed: onDismissOverlay,
          child: const Text('Dismiss overlay'),
        ),
        TextButton(
          onPressed: onRefreshDisplays,
          child: const Text('Refresh displays'),
        ),
        TextButton(
          onPressed: onRecover,
          child: const Text('Run recovery'),
        ),
        TextButton(
          onPressed: state.lifecycle == OverlayState.paused ? onResume : onPause,
          child: Text(
            state.lifecycle == OverlayState.paused ? 'Resume schedule' : 'Pause schedule',
          ),
        ),
      ],
    );
  }
}

class _StartupPanel extends StatelessWidget {
  const _StartupPanel({
    required this.startup,
    required this.onChanged,
  });

  final LaunchAtStartupService startup;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Startup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: startup.isEnabled,
              onChanged: startup.isLoading ? null : onChanged,
              title: const Text('Launch at login'),
              subtitle: Text(
                startup.isLoading
                    ? 'Updating startup setting...'
                    : 'Start StopGrinding automatically when you log in.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.settings,
    required this.isSaving,
    required this.onIntervalChanged,
    required this.onDurationChanged,
    required this.onInteractionModeChanged,
    required this.onFullscreenModeChanged,
    required this.onDismissPolicyTypeChanged,
    required this.onAllowEarlyDismissChanged,
    required this.onSave,
  });

  final OverlaySettings settings;
  final bool isSaving;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<InteractionMode> onInteractionModeChanged;
  final ValueChanged<FullscreenMode> onFullscreenModeChanged;
  final ValueChanged<DismissPolicyType> onDismissPolicyTypeChanged;
  final ValueChanged<bool> onAllowEarlyDismissChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bool canUseEarlyDismiss =
        settings.dismissPolicy.type != DismissPolicyType.timedOnly &&
        settings.interactionMode == InteractionMode.blocking;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey('interval-${settings.schedule.interval.inMinutes}'),
              value: settings.schedule.interval.inMinutes,
              decoration: const InputDecoration(labelText: 'Break interval'),
              items: _intervalOptions
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text('$minutes minutes'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onIntervalChanged(value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey('duration-${settings.duration.value.inMinutes}'),
              value: settings.duration.value.inMinutes,
              decoration: const InputDecoration(labelText: 'Overlay duration'),
              items: _durationOptions
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text('$minutes minutes'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onDurationChanged(value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<InteractionMode>(
              key: ValueKey('interaction-${settings.interactionMode.name}'),
              value: settings.interactionMode,
              decoration: const InputDecoration(labelText: 'Interaction mode'),
              items: InteractionMode.values
                  .map(
                    (mode) => DropdownMenuItem<InteractionMode>(
                      value: mode,
                      child: Text(_interactionModeLabel(mode)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onInteractionModeChanged(value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FullscreenMode>(
              key: ValueKey('fullscreen-${settings.fullscreenMode.name}'),
              value: settings.fullscreenMode,
              decoration: const InputDecoration(
                labelText: 'Fullscreen behavior',
              ),
              items: FullscreenMode.values
                  .map(
                    (mode) => DropdownMenuItem<FullscreenMode>(
                      value: mode,
                      child: Text(_fullscreenModeLabel(mode)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onFullscreenModeChanged(value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DismissPolicyType>(
              key: ValueKey('dismiss-${settings.dismissPolicy.type.name}'),
              value: settings.dismissPolicy.type,
              decoration: const InputDecoration(labelText: 'Dismiss policy'),
              items: DismissPolicyType.values
                  .map(
                    (policy) => DropdownMenuItem<DismissPolicyType>(
                      value: policy,
                      child: Text(_dismissPolicyLabel(policy)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onDismissPolicyTypeChanged(value);
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.dismissPolicy.allowEarlyDismiss &&
                  canUseEarlyDismiss,
              onChanged: canUseEarlyDismiss ? onAllowEarlyDismissChanged : null,
              title: const Text('Allow early dismiss'),
              subtitle: Text(
                canUseEarlyDismiss
                    ? 'Double-click dismissal is enabled for the current policy.'
                    : 'Requires blocking mode and a gesture-based dismiss policy.',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                child: Text(isSaving ? 'Saving…' : 'Save settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<int> _intervalOptions = <int>[15, 30, 45, 60, 90, 120];
const List<int> _durationOptions = <int>[1, 2, 3, 5, 10, 15];

String _interactionModeLabel(InteractionMode mode) {
  switch (mode) {
    case InteractionMode.blocking:
      return 'Blocking';
    case InteractionMode.passthrough:
      return 'Passthrough';
  }
}

String _fullscreenModeLabel(FullscreenMode mode) {
  switch (mode) {
    case FullscreenMode.disabled:
      return 'Do not show above fullscreen apps';
    case FullscreenMode.enabled:
      return 'Show above fullscreen apps';
  }
}

String _dismissPolicyLabel(DismissPolicyType policy) {
  switch (policy) {
    case DismissPolicyType.timedOnly:
      return 'Timed only';
    case DismissPolicyType.doubleClickAnywhere:
      return 'Double-click anywhere';
    case DismissPolicyType.doubleClickCat:
      return 'Double-click cat';
  }
}

String? _resultSummary(OverlayResult? result) {
  if (result == null) {
    return null;
  }

  switch (result.type) {
    case OverlayResultType.shown:
      return 'Overlay shown${result.sessionId == null ? '' : ' (${result.sessionId})'}';
    case OverlayResultType.dismissed:
      return 'Dismissed: ${result.dismissReason?.name ?? 'unknown'}';
    case OverlayResultType.failed:
      return 'Failed: ${result.message ?? 'unknown error'}';
  }
}

String? _formatDateTime(DateTime? value) {
  if (value == null) {
    return null;
  }

  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
}

extension on OverlaySettings {
  OverlaySettings copyWithSchedule(OverlaySchedule schedule) {
    return OverlaySettings(
      schedule: schedule,
      duration: duration,
      interactionMode: interactionMode,
      fullscreenMode: fullscreenMode,
      monitorScope: monitorScope,
      dismissPolicy: dismissPolicy,
    );
  }

  OverlaySettings copyWithDuration(OverlayDuration nextDuration) {
    return OverlaySettings(
      schedule: schedule,
      duration: nextDuration,
      interactionMode: interactionMode,
      fullscreenMode: fullscreenMode,
      monitorScope: monitorScope,
      dismissPolicy: dismissPolicy,
    );
  }

  OverlaySettings copyWithInteractionMode(InteractionMode nextMode) {
    return OverlaySettings(
      schedule: schedule,
      duration: duration,
      interactionMode: nextMode,
      fullscreenMode: fullscreenMode,
      monitorScope: monitorScope,
      dismissPolicy: dismissPolicy,
    );
  }

  OverlaySettings copyWithFullscreenMode(FullscreenMode nextMode) {
    return OverlaySettings(
      schedule: schedule,
      duration: duration,
      interactionMode: interactionMode,
      fullscreenMode: nextMode,
      monitorScope: monitorScope,
      dismissPolicy: dismissPolicy,
    );
  }

  OverlaySettings copyWithDismissPolicy(DismissPolicy nextPolicy) {
    return OverlaySettings(
      schedule: schedule,
      duration: duration,
      interactionMode: interactionMode,
      fullscreenMode: fullscreenMode,
      monitorScope: monitorScope,
      dismissPolicy: nextPolicy,
    );
  }

  OverlaySettings normalized() {
    if (dismissPolicy.type == DismissPolicyType.timedOnly ||
        interactionMode == InteractionMode.passthrough) {
      return copyWithDismissPolicy(
        DismissPolicy(
          type: dismissPolicy.type,
          allowEarlyDismiss: false,
        ),
      );
    }

    return this;
  }

  bool hasSameValues(OverlaySettings other) {
    return schedule.interval == other.schedule.interval &&
        schedule.startImmediately == other.schedule.startImmediately &&
        duration.value == other.duration.value &&
        interactionMode == other.interactionMode &&
        fullscreenMode == other.fullscreenMode &&
        monitorScope == other.monitorScope &&
        dismissPolicy.type == other.dismissPolicy.type &&
        dismissPolicy.allowEarlyDismiss == other.dismissPolicy.allowEarlyDismiss;
  }
}

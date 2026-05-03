import 'package:flutter/material.dart';

import 'package:stopgrinding/features/overlay/domain/dismiss_overlay.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_flow_state.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_service.dart';
import 'package:stopgrinding/features/overlay/domain/overlay_types.dart';
import 'package:stopgrinding/features/overlay/domain/show_overlay.dart';
import 'package:stopgrinding/features/settings/domain/save_settings.dart';

class OverlayHomeScreen extends StatefulWidget {
  const OverlayHomeScreen({
    super.key,
    required this.overlayService,
    required this.showOverlay,
    required this.dismissOverlay,
    required this.saveSettings,
  });

  final OverlayService overlayService;
  final ShowOverlay showOverlay;
  final DismissOverlay dismissOverlay;
  final SaveSettings saveSettings;

  @override
  State<OverlayHomeScreen> createState() => _OverlayHomeScreenState();
}

class _OverlayHomeScreenState extends State<OverlayHomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.overlayService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StopGrinding')),
      body: AnimatedBuilder(
        animation: widget.overlayService,
        builder: (context, _) {
          final OverlayFlowState state = widget.overlayService.state;
          final OverlaySettings settings = state.settings;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lifecycle: ${state.lifecycle.name}'),
                const SizedBox(height: 8),
                Text(
                  'Next trigger: ${_formatDateTime(state.nextTriggerAt) ?? 'unscheduled'}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Duration: ${settings.duration.value.inMinutes}m every ${settings.schedule.interval.inMinutes}m',
                ),
                const SizedBox(height: 8),
                Text(
                  'Dismiss policy: ${settings.dismissPolicy.type.name}, early dismiss: ${settings.dismissPolicy.allowEarlyDismiss}',
                ),
                const SizedBox(height: 8),
                Text('Displays: ${state.displays.length}'),
                if (state.lastDismissReason != null) ...[
                  const SizedBox(height: 8),
                  Text('Last dismiss: ${state.lastDismissReason!.name}'),
                ],
                if (state.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last error: ${state.lastError}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: () {
                        widget.showOverlay();
                      },
                      child: const Text('Show overlay'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        widget.dismissOverlay(
                          reason: OverlayDismissReason.hiddenByApp,
                        );
                      },
                      child: const Text('Dismiss overlay'),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.overlayService.refreshDisplays();
                      },
                      child: const Text('Refresh displays'),
                    ),
                    TextButton(
                      onPressed: () {
                        final OverlaySettings nextSettings = OverlaySettings(
                          schedule: OverlaySchedule(
                            interval: const Duration(minutes: 30),
                            startImmediately: false,
                          ),
                          duration: settings.duration,
                          interactionMode: settings.interactionMode,
                          fullscreenMode: settings.fullscreenMode,
                          monitorScope: settings.monitorScope,
                          dismissPolicy: settings.dismissPolicy,
                        );
                        widget.saveSettings(nextSettings);
                      },
                      child: const Text('Set 30m cadence'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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

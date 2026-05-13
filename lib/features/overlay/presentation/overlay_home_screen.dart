import 'dart:math' as math;

import 'package:flutter/material.dart' hide OverlayState;

import 'package:stopgrinding/app/shell/shell_navigation_controller.dart';
import 'package:stopgrinding/app/theme/app_theme_tokens.dart';
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
    required this.shellNavigationController,
    required this.overlayService,
    required this.launchAtStartupService,
    required this.showOverlay,
    required this.dismissOverlay,
    required this.saveSettings,
  });

  final ShellNavigationController shellNavigationController;
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
  bool _settingsSpotlightActive = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _settingsPanelKey = GlobalKey();
  int _lastShellRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    widget.overlayService.initialize();
    widget.launchAtStartupService.initialize();
    widget.shellNavigationController.addListener(_handleShellNavigation);
  }

  @override
  void dispose() {
    widget.shellNavigationController.removeListener(_handleShellNavigation);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tokens.canvasGradient,
          ),
        ),
        child: Stack(
          children: [
            const _BackdropDoodles(),
            SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  widget.overlayService,
                  widget.launchAtStartupService,
                ]),
                builder: (context, _) {
                  final OverlayFlowState state = widget.overlayService.state;
                  final LaunchAtStartupService startup =
                      widget.launchAtStartupService;
                  _syncDraftIfNeeded(state.settings);
                  final OverlaySettings settings =
                      _draftSettings ?? state.settings;
                  final List<OverlayCatalogItem> catalog = state.catalog;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool useTwoColumns = constraints.maxWidth >= 1080;
                      final double horizontalPadding =
                          constraints.maxWidth >= 900 ? 34 : 20;
                      final double topSpacing = constraints.maxWidth >= 900
                          ? 26
                          : 16;

                      final Widget primaryColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroBanner(
                            state: state,
                            catalog: catalog,
                            onShowOverlay: () {
                              widget.showOverlay();
                            },
                            onDismissOverlay: () {
                              widget.dismissOverlay(
                                reason: OverlayDismissReason.hiddenByApp,
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          _ActionsPanel(
                            state: state,
                            onRefreshDisplays:
                                widget.overlayService.refreshDisplays,
                            onRecover: widget.overlayService.recover,
                            onPause: widget.overlayService.pause,
                            onResume: widget.overlayService.resume,
                          ),
                          const SizedBox(height: 18),
                          _StartupPanel(
                            startup: startup,
                            onChanged: (enabled) {
                              widget.launchAtStartupService.setEnabled(enabled);
                            },
                          ),
                        ],
                      );

                      final Widget secondaryColumn = _SettingsPanel(
                        key: _settingsPanelKey,
                        settings: settings,
                        catalog: catalog,
                        isSaving: _isSaving,
                        isSpotlighted: _settingsSpotlightActive,
                        onIntervalChanged: (minutes) {
                          _updateDraft(
                            settings.copyWith(
                              schedule: OverlaySchedule(
                                interval: Duration(minutes: minutes),
                                startImmediately:
                                    settings.schedule.startImmediately,
                              ),
                            ),
                          );
                        },
                        onDurationChanged: (minutes) {
                          _updateDraft(
                            settings.copyWith(
                              duration: OverlayDuration(
                                Duration(minutes: minutes),
                              ),
                            ),
                          );
                        },
                        onInteractionModeChanged: (value) {
                          _updateDraft(
                            settings
                                .copyWith(interactionMode: value)
                                .normalized(catalog),
                          );
                        },
                        onFullscreenModeChanged: (value) {
                          _updateDraft(
                            settings.copyWith(fullscreenMode: value),
                          );
                        },
                        onOverlayChanged: (value) {
                          OverlayCatalogItem? selectedItem;
                          for (final OverlayCatalogItem item in catalog) {
                            if (item.id == value) {
                              selectedItem = item;
                              break;
                            }
                          }
                          _updateDraft(
                            settings.copyWith(
                              selectedOverlayId: value,
                              selectedOverlayAssetPath:
                                  selectedItem?.assetPath ??
                                  settings.selectedOverlayAssetPath,
                            ),
                          );
                        },
                        onDismissPolicyTypeChanged: (value) {
                          _updateDraft(
                            settings.copyWith(
                              dismissPolicy: DismissPolicy(
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
                            settings
                                .copyWith(
                                  dismissPolicy: DismissPolicy(
                                    type: settings.dismissPolicy.type,
                                    allowEarlyDismiss: value,
                                  ),
                                )
                                .normalized(catalog),
                          );
                        },
                        onSave: () => _saveSettings(settings, catalog),
                      );

                      return SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          topSpacing,
                          horizontalPadding,
                          28,
                        ),
                        child: Column(
                          children: [
                            _TopChrome(
                              state: state,
                              onOpenSettings: _openSettingsDeck,
                              onJumpToTop: _jumpToTop,
                            ),
                            const SizedBox(height: 18),
                            if (useTwoColumns)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 8, child: primaryColumn),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 9, child: secondaryColumn),
                                ],
                              )
                            else ...[
                              primaryColumn,
                              const SizedBox(height: 18),
                              secondaryColumn,
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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

  Future<void> _openSettingsDeck() async {
    setState(() {
      _settingsSpotlightActive = true;
    });

    final BuildContext? targetContext = _settingsPanelKey.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }

    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _settingsSpotlightActive = false;
      });
    });
  }

  Future<void> _jumpToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }

    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleShellNavigation() {
    final ShellNavigationController controller =
        widget.shellNavigationController;
    if (controller.requestVersion == _lastShellRequestVersion) {
      return;
    }
    _lastShellRequestVersion = controller.requestVersion;

    switch (controller.destination) {
      case ShellDestination.home:
        _jumpToTop();
      case ShellDestination.settings:
        _openSettingsDeck();
    }
  }

  Future<void> _saveSettings(
    OverlaySettings settings,
    List<OverlayCatalogItem> catalog,
  ) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.saveSettings(settings.normalized(catalog));
      if (!mounted) {
        return;
      }

      final bool saveSucceeded =
          widget.overlayService.state.settings.hasSameValues(
            settings.normalized(catalog),
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

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.state,
    required this.onOpenSettings,
    required this.onJumpToTop,
  });

  final OverlayFlowState state;
  final VoidCallback onOpenSettings;
  final VoidCallback onJumpToTop;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 10,
      spacing: 10,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: _badgeDecoration(tokens),
          child: InkWell(
            onTap: onJumpToTop,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(
                'StopGrinding',
                style: textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: _badgeDecoration(tokens),
              child: Text(
                state.lifecycle == OverlayState.paused
                    ? 'Scheduler paused'
                    : 'Scheduler armed',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Settings deck'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.state,
    required this.catalog,
    required this.onShowOverlay,
    required this.onDismissOverlay,
  });

  final OverlayFlowState state;
  final List<OverlayCatalogItem> catalog;
  final VoidCallback onShowOverlay;
  final VoidCallback onDismissOverlay;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final OverlayCatalogItem? selectedItem = catalog.isEmpty
        ? null
        : state.settings.selectedCatalogItem(catalog);
    final OverlayResult? result = state.lastResult;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxWidth < 700;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tokens.heroGradient,
            ),
            borderRadius: BorderRadius.circular(tokens.radiusLarge),
            border: Border.all(color: tokens.panelStroke, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: tokens.panelShadow,
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroBannerCopy(textTheme: textTheme, tokens: tokens),
                    const SizedBox(height: 18),
                    _HeroSticker(
                      title: selectedItem?.title ?? 'Loading clip',
                      extensionLabel: selectedItem == null
                          ? '...'
                          : _assetExtensionLabel(selectedItem.assetPath),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HeroBannerCopy(
                        textTheme: textTheme,
                        tokens: tokens,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _HeroSticker(
                      title: selectedItem?.title ?? 'Loading clip',
                      extensionLabel: selectedItem == null
                          ? '...'
                          : _assetExtensionLabel(selectedItem.assetPath),
                    ),
                  ],
                ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricChip(
                    label: 'Next break',
                    value:
                        _formatDateTime(state.nextTriggerAt) ?? 'unscheduled',
                  ),
                  _MetricChip(
                    label: 'Cadence',
                    value:
                        '${state.settings.duration.value.inMinutes}m / ${state.settings.schedule.interval.inMinutes}m',
                  ),
                  _MetricChip(
                    label: 'Last result',
                    value: _resultSummary(result) ?? 'waiting',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onShowOverlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Manual trigger'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDismissOverlay,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Dismiss overlay'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroBannerCopy extends StatelessWidget {
  const _HeroBannerCopy({required this.textTheme, required this.tokens});

  final TextTheme textTheme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.chrome.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            border: Border.all(color: tokens.panelStroke, width: 1.4),
          ),
          child: Text(
            'Break overlay control room',
            style: textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Make the interruption feel loud, funny, and impossible to ignore.',
          style: textTheme.displaySmall?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text(
          'Tune the cadence, pick the cat clip, and keep the overlay behavior readable without burying the controls in a flat settings slab.',
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ],
    );
  }
}

class _HeroSticker extends StatelessWidget {
  const _HeroSticker({required this.title, required this.extensionLabel});

  final String title;
  final String extensionLabel;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Transform.rotate(
      angle: -0.055,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.chrome,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(color: tokens.panelStroke, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOW LOADED',
              style: textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              extensionLabel,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel({
    required this.state,
    required this.onRefreshDisplays,
    required this.onRecover,
    required this.onPause,
    required this.onResume,
  });

  final OverlayFlowState state;
  final Future<void> Function() onRefreshDisplays;
  final Future<void> Function() onRecover;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      title: 'Debug status',
      eyebrow: 'Runtime',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusPill(
                label: 'Lifecycle',
                value: state.lifecycle.name,
                tone: state.lifecycle == OverlayState.visible
                    ? _StatusTone.success
                    : _StatusTone.neutral,
              ),
              _StatusPill(
                label: 'Displays',
                value: state.displays.length.toString(),
              ),
              _StatusPill(
                label: 'Session result',
                value: state.lastResult?.type.name ?? 'none',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TextButton(
                onPressed: onRefreshDisplays,
                child: const Text('Refresh displays'),
              ),
              TextButton(
                onPressed: onRecover,
                child: const Text('Run recovery'),
              ),
              TextButton(
                onPressed: state.lifecycle == OverlayState.paused
                    ? onResume
                    : onPause,
                child: Text(
                  state.lifecycle == OverlayState.paused
                      ? 'Resume schedule'
                      : 'Pause schedule',
                ),
              ),
            ],
          ),
          if (state.lastError != null) ...[
            const SizedBox(height: 14),
            _NoticeStrip(
              tone: _StatusTone.warn,
              message: 'Last overlay error: ${state.lastError}',
            ),
          ],
        ],
      ),
    );
  }
}

class _StartupPanel extends StatelessWidget {
  const _StartupPanel({required this.startup, required this.onChanged});

  final LaunchAtStartupService startup;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      title: 'Startup',
      eyebrow: 'macOS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            title: 'Launch at login',
            subtitle: startup.isLoading
                ? 'Updating startup setting...'
                : 'Start StopGrinding automatically when you log in.',
            value: startup.isEnabled,
            onChanged: startup.isLoading ? null : onChanged,
          ),
          if (startup.lastError != null) ...[
            const SizedBox(height: 14),
            _NoticeStrip(
              tone: _StatusTone.warn,
              message: 'Launch-at-login error: ${startup.lastError}',
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    super.key,
    required this.settings,
    required this.catalog,
    required this.isSaving,
    required this.isSpotlighted,
    required this.onIntervalChanged,
    required this.onDurationChanged,
    required this.onInteractionModeChanged,
    required this.onFullscreenModeChanged,
    required this.onOverlayChanged,
    required this.onDismissPolicyTypeChanged,
    required this.onAllowEarlyDismissChanged,
    required this.onSave,
  });

  final OverlaySettings settings;
  final List<OverlayCatalogItem> catalog;
  final bool isSaving;
  final bool isSpotlighted;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<InteractionMode> onInteractionModeChanged;
  final ValueChanged<FullscreenMode> onFullscreenModeChanged;
  final ValueChanged<String> onOverlayChanged;
  final ValueChanged<DismissPolicyType> onDismissPolicyTypeChanged;
  final ValueChanged<bool> onAllowEarlyDismissChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bool canUseEarlyDismiss =
        settings.dismissPolicy.type != DismissPolicyType.timedOnly &&
        settings.interactionMode == InteractionMode.blocking;

    return _GlassPanel(
      title: 'Settings',
      eyebrow: 'Control surface',
      isSpotlighted: isSpotlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transparent enough to feel light, structured enough to avoid accidental chaos.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (catalog.isEmpty)
            const Text('Overlay video catalog is loading...')
          else
            DropdownButtonFormField<String>(
              key: ValueKey('overlay-${settings.selectedOverlayId}'),
              isExpanded: true,
              value: settings.selectedCatalogItem(catalog).id,
              decoration: const InputDecoration(labelText: 'Break video'),
              items: catalog
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        '${item.title} (${_assetExtensionLabel(item.assetPath)})',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onOverlayChanged(value);
                }
              },
            ),
          const SizedBox(height: 16),
          _SettingGrid(
            children: [
              DropdownButtonFormField<int>(
                key: ValueKey(
                  'interval-${settings.schedule.interval.inMinutes}',
                ),
                isExpanded: true,
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
              DropdownButtonFormField<int>(
                key: ValueKey('duration-${settings.duration.value.inMinutes}'),
                isExpanded: true,
                value: settings.duration.value.inMinutes,
                decoration: const InputDecoration(
                  labelText: 'Overlay duration',
                ),
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
              DropdownButtonFormField<InteractionMode>(
                key: ValueKey('interaction-${settings.interactionMode.name}'),
                isExpanded: true,
                value: settings.interactionMode,
                decoration: const InputDecoration(
                  labelText: 'Interaction mode',
                ),
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
              DropdownButtonFormField<FullscreenMode>(
                key: ValueKey('fullscreen-${settings.fullscreenMode.name}'),
                isExpanded: true,
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
              DropdownButtonFormField<DismissPolicyType>(
                key: ValueKey('dismiss-${settings.dismissPolicy.type.name}'),
                isExpanded: true,
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
            ],
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            title: 'Allow early dismiss',
            subtitle: canUseEarlyDismiss
                ? 'Double-click dismissal is enabled for the current policy.'
                : 'Requires blocking mode and a gesture-based dismiss policy.',
            value:
                settings.dismissPolicy.allowEarlyDismiss && canUseEarlyDismiss,
            onChanged: canUseEarlyDismiss ? onAllowEarlyDismissChanged : null,
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: Icon(isSaving ? Icons.hourglass_top_rounded : Icons.save),
              label: Text(isSaving ? 'Saving…' : 'Save settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingGrid extends StatelessWidget {
  const _SettingGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useTwoColumns = constraints.maxWidth >= 520;
        if (!useTwoColumns) {
          return Column(
            children: [
              for (int index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map(
                (child) => SizedBox(
                  width: math.max(220, (constraints.maxWidth - 16) / 2),
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.title,
    required this.child,
    this.eyebrow,
    this.isSpotlighted = false,
  });

  final String title;
  final String? eyebrow;
  final Widget child;
  final bool isSpotlighted;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isSpotlighted
            ? tokens.chrome.withValues(alpha: 0.94)
            : tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
        border: Border.all(
          color: isSpotlighted ? tokens.accent : tokens.panelStroke,
          width: isSpotlighted ? 2.6 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isSpotlighted
                ? tokens.accent.withValues(alpha: 0.28)
                : tokens.panelShadow,
            blurRadius: isSpotlighted ? 30 : 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

enum _StatusTone { neutral, success, warn }

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    this.tone = _StatusTone.neutral,
  });

  final String label;
  final String value;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color background;

    switch (tone) {
      case _StatusTone.neutral:
        background = tokens.chrome.withValues(alpha: 0.9);
      case _StatusTone.success:
        background = tokens.success.withValues(alpha: 0.45);
      case _StatusTone.warn:
        background = tokens.warn.withValues(alpha: 0.18);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.panelStroke, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(color: tokens.panelStroke, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({required this.tone, required this.message});

  final _StatusTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;
    final Color tint = tone == _StatusTone.warn ? tokens.warn : tokens.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tint, width: 1.2),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _BackdropDoodles extends StatelessWidget {
  const _BackdropDoodles();

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = Theme.of(
      context,
    ).extension<AppThemeTokens>()!;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -50,
            child: _Blob(
              size: 240,
              color: tokens.accent.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            left: -40,
            top: 120,
            child: _Blob(
              size: 160,
              color: tokens.accentMuted.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -60,
            left: 80,
            child: _Blob(
              size: 220,
              color: tokens.success.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.42),
      ),
    );
  }
}

BoxDecoration _badgeDecoration(AppThemeTokens tokens) {
  return BoxDecoration(
    color: tokens.chrome.withValues(alpha: 0.88),
    borderRadius: BorderRadius.circular(tokens.radiusSmall),
    border: Border.all(color: tokens.panelStroke, width: 1.4),
  );
}

String _assetExtensionLabel(String assetPath) {
  final List<String> segments = assetPath.split('.');
  final String extension = segments.length > 1 ? segments.last : '';
  return extension.isEmpty ? 'asset' : extension.toUpperCase();
}

const List<int> _intervalOptions = <int>[1, 15, 30, 45, 60, 90, 120];
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
      return 'Double-click media';
  }
}

String? _resultSummary(OverlayResult? result) {
  if (result == null) {
    return null;
  }

  switch (result.type) {
    case OverlayResultType.shown:
      return 'shown';
    case OverlayResultType.dismissed:
      return 'dismissed';
    case OverlayResultType.failed:
      return 'failed';
  }
}

String? _formatDateTime(DateTime? value) {
  if (value == null) {
    return null;
  }

  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

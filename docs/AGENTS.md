# docs/AGENTS.md

## Purpose
Source of truth for Codex and human contributors building `stopgrinding`.
Goal: preserve context with minimal tokens, avoid re-deciding architecture, and reduce hallucination risk by making product, system, and implementation decisions explicit.

## Strict Compliance Rule
AGENT SHOULD STRICTLY FOLLOW THIS MD FILE. If any planned code, architecture, naming, folder structure, or behavior conflicts with this file, the agent must stop, ask the user for permission, then update this file and the code together so docs and implementation stay synchronized.

## Product Summary
- Desktop app for macOS first, Windows second.
- Every `1h` by default, show an overlay above user apps.
- Overlay duration: `2m` by default.
- Overlay content: animated cat walks in, stays, leaves.
- Main app shell: `Flutter`.
- Overlay engine: native per platform.

## Locked Decisions
- Main UI tech: `Flutter`.
- macOS overlay tech: `Swift + AppKit`.
- Windows later: native overlay engine behind the same Dart contract.
- Native communication: `Pigeon` as primary typed RPC boundary.
- Flutter must not call raw platform channels from widgets or random services.
- Overlay windows are created `per display`; do not use one giant cross-display window.
- App requires `no Accessibility permission`.
- App requires `no Screen Recording permission`.
- Overlay monitor scope: `all monitors`.
- `Do Not Disturb` / presentation awareness: ignore in v1 unless later requested.
- User-configurable behaviors:
  - blocking vs non-blocking overlay
  - show above fullscreen apps or not
  - early dismiss behavior
- Dismiss examples allowed: double click cat, double click anywhere.

## Non-Goals For V1
- No Windows implementation now.
- No OS-level permissions beyond normal app/startup permissions.
- No screen-content inspection.
- No complex background agent/daemon unless required by implementation constraints.
- No direct dependency of feature/domain logic on AppKit or Win32.

## Architecture
Use a lightweight feature-first architecture plus explicit pattern mapping.

### Top-Level Structure
1. `app`
- app bootstrap
- DI
- routes

2. `features`
- feature-first modules
- current modules:
  - `overlay`
  - `settings`
  - `scheduler`

3. `core`
- shared types
- utils
- logging

4. `platform`
- typed native bridge and platform-facing integration

5. `macos native`
- Swift/AppKit implementation

Rule: keep the structure feature-first and lightweight. Do not create deep generic folder trees unless the codebase actually needs them.

## Required Design Patterns
Patterns are chosen from Refactoring.Guru catalog and are mandatory unless a later decision update changes them.

### 1. Bridge
Use to separate Dart abstraction from native implementation.

- Abstraction: `OverlayController`
- Implementor: `OverlayBridge`
- Concrete implementors:
  - `MacOSOverlayBridge`
  - `WindowsOverlayBridge` later

Rule: app logic depends on `OverlayController`, not AppKit, not channel details.

### 2. Facade
Use simplified entrypoints on both sides of the bridge.

- Dart facade: `OverlayService`
- Native facade: `OverlayFacade`

Rule: Flutter and feature logic should not coordinate multiple native objects directly.

### 3. Command
Every cross-boundary request should be represented as an explicit command or typed request DTO.

Examples:
- `ShowOverlayCommand`
- `HideOverlayCommand`
- `SaveSettingsCommand`
- `RefreshDisplaysCommand`

Rule: avoid ad-hoc string method calls and loosely typed maps.

### 4. State
Overlay lifecycle must be explicit.

Canonical states:
- `idle`
- `scheduled`
- `preparing`
- `visible`
- `dismissed`
- `cooldown`
- `paused`

Rule: do not model lifecycle with scattered booleans.

### 5. Strategy
Runtime behavior must be encapsulated as strategies, not `if/else` spread across services.

Strategy families:
- scheduling strategy
- interaction strategy
- fullscreen strategy
- dismiss strategy

### 6. Observer
Native -> Flutter events must flow through subscription/event stream semantics.

Examples:
- `overlayShown`
- `overlayDismissed`
- `overlayFailed`
- `displayTopologyChanged`

### 7. Abstract Factory
Use for constructing platform-specific families.

Example family members:
- window manager
- animation host
- dismiss handler
- display service

Rule: Windows support should be added by implementing another family, not rewriting app logic.

### 8. Mediator
Use inside the native subsystem to avoid direct coupling between overlay windows, animation, display handling, and dismissal logic.

- Native mediator/coordinator: `OverlayCoordinator`

## Native Communication Rules
- Preferred bridge tool: `Pigeon`.
- Allowed fallback: `EventChannel` for event streams only if needed.
- Avoid raw `MethodChannel` unless there is a documented reason.
- One typed contract file should define the RPC boundary.
- RPC boundary must be narrow and stable.
- DTOs must be versionable and enum-driven where possible.

## Contract Shape
Recommended Pigeon APIs:

### Host API
- `initialize()`
- `showOverlay(OverlayRequestDto request)`
- `hideOverlay(HideOverlayRequestDto request)`
- `updateSettings(OverlaySettingsDto settings)`
- `refreshDisplays()`
- `getOverlayStatus()`

### Flutter API
- `onOverlayShown(OverlaySessionDto session)`
- `onOverlayDismissed(OverlayDismissedDto event)`
- `onOverlayFailed(OverlayErrorDto error)`
- `onDisplayTopologyChanged(DisplayTopologyDto topology)`

## Feature Model
Use value objects and enums. Avoid flat bags of booleans.

### Core Types
- `OverlaySession`
- `OverlaySettings`
- `OverlaySchedule`
- `DisplayTarget`
- `OverlayDuration`
- `DismissPolicy`

### Enums
- `InteractionMode { blocking, passthrough }`
- `FullscreenMode { disabled, enabled }`
- `MonitorScope { allDisplays }`
- `DismissPolicyType { timedOnly, doubleClickAnywhere, doubleClickCat }`

## macOS Native Subsystem
Must use AppKit.

### Core Classes
- `OverlayFacade`
- `OverlayCoordinator`
- `OverlayWindowManager`
- `OverlayWindowController`
- `DisplayService`
- `AnimationHost`
- `DismissHandler`
- `OverlayApiImpl`
- `OverlayEvents`

### Responsibilities
- `OverlayFacade`: simple entrypoint for bridge layer
- `OverlayCoordinator`: lifecycle orchestration and state transitions
- `OverlayWindowManager`: create/manage one overlay window per display
- `OverlayWindowController`: per-window control
- `DisplayService`: discover and refresh screens
- `AnimationHost`: host cat animation technology
- `DismissHandler`: translate user gestures into dismiss actions

## Flutter/Dart Responsibilities
### `app`
- bootstrap
- DI
- routing

### `features/overlay`
- main overlay domain and app logic
- `OverlayController`
- `OverlayService`
- `ShowOverlay`
- `DismissOverlay`

### `features/settings`
- settings UI
- settings persistence orchestration
- `SaveSettings`

### `features/scheduler`
- schedule logic
- `SchedulerService`
- timer strategies

### `platform/bridge`
- `OverlayBridge`
- `PigeonOverlayBridge`
- native event wiring

## Timer / Scheduling Rules
- Default interval: `1h`
- Default overlay duration: `2m`
- Schedule logic belongs in Dart feature layers.
- Native side should execute overlay windowing, not own business scheduling policy unless later justified.

## Multi-Display Rules
- Always target `all monitors`.
- Create one native window per active display.
- Never assume a single-monitor environment.
- Display topology changes should emit an event and refresh active window plan.

## Fullscreen Rules
- Fullscreen-on/off is user-configurable.
- Implementation should be encapsulated behind fullscreen strategy.
- If macOS edge cases appear, preserve the contract and adjust native strategy only.

## Interaction Rules
- `blocking`: overlay receives events
- `passthrough`: overlay ignores mouse events
- Interaction behavior must be runtime-switchable from settings.

## Dismiss Rules
- Always support timeout-based dismiss.
- Optional user dismiss mode from settings.
- Dismiss policy should be strategy-based, not hardcoded into window classes.

## Animation Rules
- Preferred first choice: `Rive` if cat asset style fits.
- Acceptable alternatives: sprite sheet, APNG, transparent video, native image sequence.
- Animation tech must be isolated behind `AnimationHost`.
- Do not leak animation vendor SDK through feature/domain logic.

## Persistence
- Store settings locally.
- Acceptable options: `shared_preferences`, `Hive`.
- Keep persistence behind repository interfaces.

## Startup / Distribution
- Support launch at login.
- If distributing outside App Store, consider `Sparkle` later for updates.
- Update system is not part of overlay core architecture.

## Suggested Repo Layout
```text
docs/
  AGENTS.md
  PLAYBOOK.md

lib/
  app/
  core/
    types/
    utils/
    logging/
  features/
    overlay/
      domain/
      application/
      infrastructure/
      presentation/
    settings/
      domain/
      application/
      infrastructure/
      presentation/
    scheduler/
      domain/
      application/
      infrastructure/
  platform/
    bridge/

pigeons/
  overlay_api.dart

macos/
  Runner/
    Overlay/
      overlay_facade.swift
      overlay_coordinator.swift
      overlay_window_manager.swift
      overlay_window_controller.swift
      display_service.swift
      animation_host.swift
      dismiss_handler.swift
      overlay_api_impl.swift
      overlay_events.swift
```

## Hard Rules For Codex
- Read this file before making architecture decisions.
- Do not invent permissions not listed here.
- Do not introduce direct widget -> platform channel calls.
- Do not collapse layers for convenience.
- Do not replace typed bridge with loosely typed maps/strings.
- Do not move business scheduling into AppKit unless a documented constraint forces it.
- Do not use singletons as the primary architecture mechanism.
- Do not add Windows-specific logic into macOS classes or vice versa.
- If a request or implementation idea conflicts with this file, stop and ask the user for permission before proceeding.
- If changing a locked decision, update this file in the same change as the code.

## Decision Updates
- `2026-04-28`: Initial architecture and product decisions recorded from user discussion.
- `2026-04-28`: Simplified from a heavier layered repo plan to a lighter feature-first structure with shorter class names.
- `2026-04-29`: Moved markdown docs under `docs/` and kept repo layout aligned with that change.
- `2026-04-29`: Recreated the Flutter project from scratch after macOS desktop support became available locally.

## Source References
- Design pattern catalog: https://refactoring.guru/design-patterns/catalog
- Bridge: https://refactoring.guru/design-patterns/bridge
- Facade: https://refactoring.guru/design-patterns/facade
- Command: https://refactoring.guru/design-patterns/command
- Strategy: https://refactoring.guru/design-patterns/strategy
- State: https://refactoring.guru/design-patterns/state
- Observer: https://refactoring.guru/design-patterns/observer
- Mediator: https://refactoring.guru/design-patterns/mediator
- Abstract Factory: https://refactoring.guru/design-patterns/abstract-factory

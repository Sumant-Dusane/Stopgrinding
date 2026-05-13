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
- Overlay content: user-selectable bundled overlay media chosen from app-managed asset folders.
- Main app shell: `Flutter`.
- Overlay engine: native per platform.
- Settings surface should feel light and transparent rather than panel-heavy.
- The macOS shell should expose a persistent menu bar entrypoint that can reopen the app and jump into settings quickly.
- Visual direction should be funny and comic-like, while remaining easy to retheme centrally.

## Locked Decisions
- Main UI tech: `Flutter`.
- macOS overlay tech: `Swift + AppKit`.
- macOS media playback should prefer native Apple media/view APIs over HTML/WebKit rendering.
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
- User-configurable overlay content:
  - selected bundled media item from app-managed asset catalog, rendered from its Flutter `assetPath`
- Dismiss examples allowed: double click cat, double click anywhere.
- macOS distribution must support app-update messaging for newly shipped overlay media content.
- Theme customization must be centralized so a major visual retheme can be done in at most `3 files` without widespread widget refactors.

## Non-Goals For V1
- No Windows implementation now.
- No OS-level permissions beyond normal app/startup permissions.
- No screen-content inspection.
- No complex background agent/daemon unless required by implementation constraints.
- No direct dependency of feature/domain logic on AppKit or Win32.
- No user-imported media filesystem picker in v1; overlay choices come from shipped Flutter assets and app updates.
- No cross-platform web renderer for overlay media in the steady-state macOS path unless a format has no practical native fallback and the decision is documented.

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

Rule: bundled overlay media metadata should come from one manifest source when practical, rather than duplicated hardcoded catalog lists across Dart and Swift.
Rule: runtime overlay rendering should use the selected Flutter `assetPath` as the source of truth; catalog metadata exists for selection UX and labeling, not native format lookup.

## Feature Model
Use value objects and enums. Avoid flat bags of booleans.

### Core Types
- `OverlaySession`
- `OverlaySettings`
- `OverlaySchedule`
- `DisplayTarget`
- `OverlayDuration`
- `DismissPolicy`
- `OverlayCatalogItem`
- `ThemeSpec`

### Media Catalog Rules
- Bundle shipped overlay media under Flutter `assets/`.
- Keep a single shared Dart source of truth for shipped overlay videos in `lib/core/constants/overlay_videos.dart`.
- Each video entry should declare:
  - `id`
  - `title`
  - `assetPath`
  - `loopStart`
  - optional `loopEnd`
- Native rendering should load the selected Flutter `assetPath` directly from the app bundle.
- Prefer video formats with first-class macOS-native playback support, such as `mov`, `mp4`, and `m4v`.
- Avoid treating `webm` as a primary product format for macOS unless a documented native playback path is intentionally adopted.
- Treat image-based overlay formats as out of scope for the simplified macOS pipeline.
- Overlay media should render in a padded viewport-safe presentation area rather than being hard-flush to the screen edges.
- The current macOS presentation is a bottom-right anchored media card that slides in from the right when shown.
- Loop metadata should describe the steady-state seamless segment; if the asset has an intro, native playback may play the intro once and then loop only the declared segment.
- If the product expects the user desktop to show through around the subject, the shipped video asset itself must include alpha transparency.

### Enums
- `InteractionMode { blocking, passthrough }`
- `FullscreenMode { disabled, enabled }`
- `MonitorScope { allDisplays }`
- `DismissPolicyType { timedOnly, doubleClickAnywhere, doubleClickCat }`

Rule: `DismissPolicyType.doubleClickCat` should be interpreted as double-clicking the active media subject/hit area until a more neutral rename is introduced in a contract-safe phase.

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
- `AnimationHost`: host overlay media rendering technology and overlay media lifecycle
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
- overlay catalog selection
- theme application entrypoint

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
- Primary bundled overlay media formats are macOS-native video files such as `MOV`, `MP4`, and `M4V`.
- Video assets should live in app-managed asset folders with metadata sufficient for user-facing labels and selection.
- Media rendering tech must stay isolated behind `AnimationHost` or a renamed equivalent abstraction; Flutter app logic must not know the rendering vendor.
- The chosen media item should be resolved from persisted settings, not hardcoded in native overlay classes.
- The default add/remove workflow for shipped media should be:
  - edit `lib/core/constants/overlay_videos.dart`
  - add or remove the referenced media file

## Persistence
- Store settings locally.
- Acceptable options: `shared_preferences`, `Hive`.
- Keep persistence behind repository interfaces.
- Persist the selected overlay media id and active theme id alongside other settings.

## Startup / Distribution
- Support launch at login.
- If distributing outside App Store, use a real update path such as `Sparkle` or an equivalent release-feed solution so users can discover app updates that add new media content.
- Update system is not part of overlay core architecture.

## App Shell UX Rules
- The settings experience should use transparent or translucent surfaces where macOS allows it without harming readability.
- Add a small always-available macOS shell entrypoint above or alongside the app bar/title area that opens settings quickly.
- The quick-open nudge should be app-shell behavior, not native overlay-window behavior.

## Theme System Rules
- Centralize app theming behind a small set of theme-definition files and reusable tokens.
- Widget code should consume semantic theme tokens/components rather than hardcoded colors, radii, or typography values.
- A broad visual restyle should require changing no more than `3 files` in the normal case:
  - theme tokens/spec
  - theme mapping/composition
  - optional asset/font registration
- Avoid scattering comic styling choices across screens.

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
- `2026-05-08`: Product direction changed from cat-specific animation to user-selectable bundled overlay media with update-driven content expansion.
- `2026-05-08`: App shell should move toward transparent settings surfaces, a comic visual theme, and a top-chrome macOS nudge that opens settings quickly.
- `2026-05-08`: Distribution planning now includes update messaging or auto-update support so users can receive newly shipped overlay media content.
- `2026-05-09`: Bundled overlay media support expanded beyond GIF to include WebM as a first-class product format.
- `2026-05-09`: Bundled overlay video entries are now maintained from a shared Dart source so add/remove changes are centralized in app code.

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

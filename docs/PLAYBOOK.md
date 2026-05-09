# docs/PLAYBOOK.md

## Purpose
Execution plan for building `stopgrinding` in memory-safe phases.
Each phase is designed so Codex can finish it, write back the key outcomes, and safely continue later after memory is cleared.

## Strict Compliance Rule
AGENT SHOULD STRICTLY FOLLOW `docs/AGENTS.md` AND THIS FILE. If any work conflicts with either markdown file, the agent must stop, ask the user for permission, then update docs and code together so they stay synchronized.

## How To Use This File
- Before each phase, read `docs/AGENTS.md` and this file.
- Execute only the current phase unless the user explicitly expands scope.
- At phase end, update the phase checklist and append a short handoff note.
- Do not start the next phase until the current phase has:
  - code complete
  - local verification complete or explicitly blocked
  - docs updated if decisions changed

## Global Rules
- Respect all locked decisions in `docs/AGENTS.md`.
- Keep architecture stable; expand via interfaces, not shortcuts.
- Prefer small verifiable increments over broad unfinished scaffolding.
- If a phase uncovers a major change, update `docs/AGENTS.md` before moving on.
- Use the lighter feature-first structure, not a deep enterprise folder tree.

## Phase Status
- Completed:
  - Phase 1: Repo Bootstrap
  - Phase 2: Feature Models And Contracts
  - Phase 3: Bridge Foundation
  - Phase 4: Overlay Flow And State
  - Phase 5: macOS Window Core
  - Phase 6: Interaction And Dismiss
  - Phase 7: Animation Integration
  - Phase 8: Settings UI And Persistence
  - Phase 9: Startup And Debugging
  - Phase 10: Polish And Release Readiness
  - Phase 11: GIF Catalog And Contract Refresh
- Current phase: Phase 12: Native macOS Media Pipeline

## Phase Format
Each phase must produce:
- code/artifacts
- verification result
- decision updates if any
- handoff summary for next phase

---

## Phase 1: Repo Bootstrap
### Goal
Create the project skeleton and baseline structure so later phases work inside a stable architecture.

### Scope
- Initialize Flutter desktop project if not already present.
- Ensure macOS desktop target is enabled.
- Create the high-level folder layout from `docs/AGENTS.md`.
- Add placeholder files/interfaces where needed to lock structure.
- Add `pigeons/` directory.
- Add base docs:
  - `docs/AGENTS.md`
  - `docs/PLAYBOOK.md`
  - optional `README.md` if useful

### Deliverables
- Flutter desktop project compiles at baseline.
- `docs/` contains the project markdown source of truth.
- Folder structure exists for:
  - `docs`
  - `app`
  - `core`
  - `features/overlay`
  - `features/settings`
  - `features/scheduler`
  - `platform/bridge`
  - `pigeons`
  - `macos/Runner/Overlay`

### Verification
- `flutter doctor` relevant checks if available
- `flutter run -d macos` or `flutter build macos` baseline if environment allows

### Exit Criteria
- Repo is buildable baseline.
- Lightweight architecture folders exist.
- No business logic or native overlay logic yet.

### Handoff Note Template
- bootstrap status
- build status
- missing tool/dependency blockers

---

## Phase 2: Feature Models And Contracts
### Goal
Define the stable language of the system before implementing behavior.

### Scope
- Implement core Dart types:
  - `OverlaySettings`
  - `OverlaySession`
  - `DisplayTarget`
  - schedule/duration value objects
- Define enums:
  - interaction mode
  - fullscreen mode
  - dismiss policy
  - overlay state
- Define interfaces:
  - `OverlayController`
  - `OverlaySettingsRepository`
  - `BreakScheduler`
  - event source abstractions
- Create initial Pigeon contract file:
  - Host API
  - Flutter API
  - DTOs

### Deliverables
- Pure Dart feature/domain types with no Flutter/native leakage.
- Pigeon schema drafted and aligned with `docs/AGENTS.md`.

### Verification
- static analysis passes
- Pigeon definitions are syntactically valid

### Exit Criteria
- Core concepts are explicit and typed.
- No UI, no AppKit implementation yet.
- Contract is ready for code generation in next phase.

### Handoff Note Template
- final types created
- open contract questions, if any
- generated vs pending artifacts

---

## Phase 3: Bridge Foundation
### Goal
Create the typed communication boundary between Flutter and macOS without implementing full overlay behavior.

### Scope
- Generate Pigeon artifacts.
- Implement Dart bridge classes:
  - `OverlayBridge`
  - `PigeonOverlayBridge`
  - event wiring
- Implement Swift bridge entrypoints:
  - `OverlayApiImpl`
  - `OverlayEvents`
- Add minimal stub behavior:
  - initialize
  - show request accepted
  - hide request accepted
  - status retrieval

### Deliverables
- End-to-end typed call path from Dart to Swift and back.
- Native side can receive commands and send test events.

### Verification
- build generated code successfully
- trigger a simple test call from Flutter to native
- confirm event callback reaches Dart

### Exit Criteria
- Bridge is real and testable.
- Still no real window overlay logic required.

### Handoff Note Template
- generated files location
- working RPC methods
- unresolved generation/build issues

---

## Phase 4: Overlay Flow And State
### Goal
Implement orchestration logic in Dart so overlay behavior is driven by clean actions and explicit state.

### Scope
- Implement:
  - `OverlayService`
  - `ShowOverlay`
  - `DismissOverlay`
  - `SaveSettings`
  - `SchedulerService`
- Implement explicit overlay lifecycle state handling.
- Connect event callbacks from native bridge into app state.
- Add timer/scheduling strategy abstraction and default hourly strategy.

### Deliverables
- Dart-side orchestration works independently of real native overlay visuals.
- A debug path can request `showOverlay()` and process dismissal/state transitions.

### Verification
- unit tests for state transitions where practical
- manual debug invocation path works

### Exit Criteria
- app logic is not coupled to AppKit specifics
- lifecycle is explicit and traceable

### Handoff Note Template
- implemented actions/services
- state transition rules
- known race/edge cases

---

## Phase 5: macOS Window Core
### Goal
Implement real AppKit overlay windows across all monitors.

### Scope
- Implement native classes:
  - `OverlayFacade`
  - `OverlayCoordinator`
  - `OverlayWindowManager`
  - `OverlayWindowController`
  - `DisplayService`
- Create one borderless transparent window per display.
- Support always-on-top behavior.
- Support all-monitor display plan.
- Add window show/hide orchestration.

### Deliverables
- real overlay windows appear on all active displays
- overlay can be shown and hidden from Flutter command path

### Verification
- manual test on single-monitor setup
- manual test on multi-monitor setup if available
- verify window lifecycle does not crash on repeated show/hide

### Exit Criteria
- AppKit overlay core works without animation polish
- display handling is centralized in native subsystem

### Handoff Note Template
- window levels/flags used
- multi-display behavior
- known fullscreen/space limitations

---

## Phase 6: Interaction And Dismiss
### Goal
Add user-configurable runtime behaviors without polluting core window logic.

### Scope
- Implement strategy families on native side and Dart config mapping:
  - blocking/passthrough interaction
  - fullscreen on/off behavior
  - dismiss policies
- Implement `DismissHandler`.
- Add double-click dismiss support according to selected policy.
- Ensure timeout-based dismissal remains supported.

### Deliverables
- settings can alter overlay behavior at runtime
- dismiss behavior is strategy-based and testable

### Verification
- manual tests for:
  - blocking mode
  - passthrough mode
  - timed dismiss
  - double click dismiss
  - fullscreen preference

### Exit Criteria
- runtime behaviors are not hardcoded in window classes
- settings map cleanly to strategy implementations

### Handoff Note Template
- implemented strategies
- settings-to-strategy mapping
- macOS edge cases found

---

## Phase 7: Animation Integration
### Goal
Integrate the cat animation in a replaceable way.

### Scope
- Implement `AnimationHost` abstraction.
- Integrate preferred animation tech, likely `Rive`.
- Render cat animation inside overlay windows.
- Support show, idle/stay, exit timing coordination.
- Keep animation vendor details out of app logic.

### Deliverables
- visible animated cat on overlay windows
- animation controlled by native overlay lifecycle

### Verification
- animation renders reliably on repeated sessions
- no obvious flicker or lifecycle leaks

### Exit Criteria
- animation is isolated behind `AnimationHost`
- switching animation tech later remains feasible

### Handoff Note Template
- animation tech chosen
- asset requirements
- rendering/performance issues

---

## Phase 8: Settings UI And Persistence
### Goal
Expose all agreed user-configurable options through Flutter UI and local persistence.

### Scope
- Build settings screens for:
  - interval
  - duration
  - interaction mode
  - fullscreen behavior
  - dismiss policy
- Implement repository-backed persistence.
- Load settings at startup and push updates to app/native layers.

### Deliverables
- usable settings UI
- persistent preferences
- settings changes reflected in overlay behavior

### Verification
- manual restart persistence test
- manual runtime update test

### Exit Criteria
- user-facing behavior is configurable
- settings flow is stable end-to-end

### Handoff Note Template
- final settings supported
- persistence backend used
- UX rough edges

---

## Phase 9: Startup And Debugging
### Goal
Make the app usable as a real background utility.

### Scope
- Add launch-at-login support.
- Add app status/debug screen:
  - current overlay state
  - next trigger time
  - last overlay result
  - manual trigger button
- Improve error logging and failure reporting.
- Handle display refresh and basic recovery paths.

### Deliverables
- app can start with system login
- debug tooling exists for troubleshooting
- common failures are visible instead of silent

### Verification
- login item/manual startup check
- manual trigger and state screen test

### Exit Criteria
- app is operable and diagnosable in day-to-day use

### Handoff Note Template
- startup integration result
- debug tooling summary
- remaining reliability gaps

---

## Phase 10: Polish And Release Readiness
### Goal
Stabilize the macOS product for real use before Windows work begins.

### Scope
- refine timing and transitions
- improve window polish
- test repeated overlay cycles
- clean dead code and naming
- add or strengthen tests where useful
- finalize docs and decision updates

### Deliverables
- stable v1-quality macOS implementation
- docs aligned with actual code

### Verification
- repeated manual sessions
- build/release verification
- final architecture review against `docs/AGENTS.md`

### Exit Criteria
- no major architecture drift
- no known critical lifecycle bug
- ready for user testing or packaging

### Handoff Note Template
- release readiness status
- known non-blocking issues
- recommended next step

---

## Phase 11: Media Catalog And Contract Refresh
### Goal
Replace cat-specific overlay assumptions with a durable bundled-media catalog model and selection flow.

### Scope
- update Dart domain types and Pigeon DTOs for:
  - selected overlay media id
  - overlay catalog item metadata
  - optional catalog-fetch bridge call
- remove new product/docs assumptions that depend on a single cat animation
- define bundled asset folder conventions and a one-stop catalog manifest for media organization, format, and labels
- update settings flow design so users can choose a media item from a dropdown or equivalent selector
- preserve existing overlay lifecycle and dismiss behavior while making content source replaceable

### Deliverables
- code and docs no longer assume a single cat asset
- typed catalog model exists across Flutter and native boundary
- asset-folder convention is documented and ready for implementation

### Verification
- static analysis
- contract generation/build verification
- settings selection state round-trip test where practical

### Exit Criteria
- overlay content is modeled as selectable catalog data, not a hardcoded animation choice
- contract stays stable enough for later updater and UI work

### Handoff Note Template
- catalog model added
- asset conventions decided
- open migration risks

---

## Phase 12: Transparent Settings And Comic Theme System
### Goal
Revamp the app shell into a transparent comic-style experience with a maintainable theme architecture.

### Scope
- introduce centralized theme tokens/specs and theme composition entrypoints
- refactor UI surfaces to consume semantic theme values instead of local styling
- redesign settings screen toward transparent/translucent panels with readability safeguards
- define a comic visual language:
  - typography
  - color tokens
  - card/chrome treatment
  - button/input styling
- ensure future broad theme swaps can usually be done in at most `3 files`

### Deliverables
- maintainable theme system with centralized tokens
- comic-style Flutter shell
- transparent settings treatment aligned with macOS conventions

### Verification
- `flutter test`
- `flutter analyze`
- manual visual check on desktop sizes
- confirm a theme variant can be swapped by touching only the intended theme files

### Exit Criteria
- app styling is centralized and reusable
- settings UI is visually revamped without scattering style logic across features

### Handoff Note Template
- theme files introduced
- transparency constraints
- remaining visual debt

---

## Phase 13: macOS Quick-Open Nudge And Settings UX Flow
### Goal
Add a lightweight macOS entrypoint that opens settings quickly without depending on the main screen layout.

### Scope
- design and implement a small macOS top-chrome nudge above or alongside the title/app bar
- clicking the nudge should reveal or focus the settings experience
- keep this behavior in app-shell/macOS shell integration, not in overlay windows
- refine settings navigation around the new media selector and transparent layout
- ensure the quick-open affordance works consistently after launch-at-login and on repeated opens

### Deliverables
- persistent quick-open settings affordance in the macOS shell
- cleaner settings entry flow for day-to-day use

### Verification
- manual open/focus flow testing
- restart/login-item retest
- no regression in overlay scheduling while settings are opened repeatedly

### Exit Criteria
- users can reach settings quickly without hunting through the main app content
- shell entrypoint does not compromise existing architecture boundaries

### Handoff Note Template
- nudge placement used
- focus/open behavior
- macOS-specific limitations

---

## Phase 14: Update Delivery And Media Content Expansion
### Goal
Ship a real update path so users can discover and install app releases that add new media packs.

### Scope
- choose and integrate macOS update delivery:
  - `Sparkle` preferred if compatible with distribution path
  - equivalent release-feed solution acceptable if better suited
- add user-facing update messaging/status surface
- document release process for shipping new media assets through app updates
- ensure update checks do not leak into overlay-domain logic
- connect the updater UX to the media catalog story so users understand why an update matters

### Deliverables
- working update mechanism or clearly bounded release-feed notifier
- docs for packaging and shipping new media content
- user-visible update affordance/message

### Verification
- build verification with updater integration
- manual update-check path if environment allows
- docs review for release flow completeness

### Exit Criteria
- users have a supported path to receive newly released media content
- updater logic is kept separate from overlay scheduling/runtime logic

### Handoff Note Template
- updater choice
- release flow summary
- signing/notarization blockers

---

## Optional Phase 15: Windows Port
### Goal
Add Windows by implementing the same abstraction family, not by altering app logic.

### Scope
- implement `WindowsOverlayBridge`
- create Windows native overlay family
- map existing contracts and strategies

### Exit Criteria
- Dart app logic requires minimal or no changes

---

## End-Of-Phase Checklist
- code compiles or build blocker documented
- verification performed or blocker documented
- `docs/AGENTS.md` updated if any decision changed
- `docs/PLAYBOOK.md` updated if phase scope changed
- short handoff note written for next phase

## Recommended Handoff Block
Append this to the end of the active work summary after each phase:

```text
Phase Complete:
- phase: <name>
- completed artifacts:
- verification:
- blockers:
- decision changes:
- next phase entrypoint:
```

Phase Complete:
- phase: Phase 5: macOS Window Core
- completed artifacts: `OverlayFacade`, `OverlayCoordinator`, `OverlayWindowManager`, `OverlayWindowController`, and `DisplayService` now back the Pigeon host API; one transparent borderless overlay window is created per active display and rebuilt on display-topology changes.
- verification: `flutter test`; `flutter build macos`
- blockers: no manual multi-monitor validation was possible in this environment
- decision changes: none
- next phase entrypoint: implement interaction, fullscreen, and dismiss policies as strategy-based native behaviors without pushing that logic into the window classes

Phase Complete:
- phase: Phase 6: Interaction And Dismiss
- completed artifacts: native `InteractionStrategy`, `FullscreenStrategy`, and `DismissStrategy` implementations now configure runtime overlay behavior; `DismissHandler` drives timeout and double-click dismissal and reports native dismiss events back to Flutter; live `updateSettings()` calls reconfigure a visible overlay session.
- verification: `flutter test`; `flutter build macos`
- blockers: no manual verification was possible for fullscreen-above-apps behavior or the double-click dismiss paths
- decision changes: none
- next phase entrypoint: replace the placeholder break card with an `AnimationHost` abstraction and integrate the first cat animation path without coupling Flutter app logic to the rendering vendor

Phase Complete:
- phase: Phase 7: Animation Integration
- completed artifacts: added native `AnimationHost` abstraction in `macos/Runner/Overlay/animation_host.swift`; integrated the first AppKit-backed cat animation path with enter, idle, and exit phases; wired animation lifecycle to native overlay show/hide without exposing animation implementation details to Flutter app logic.
- verification: `flutter test`; `flutter build macos`
- blockers: no manual visual verification was possible for timing polish or repeated animation cycles in this environment
- decision changes: first implementation uses a native AppKit animation host with an animated cat sprite placeholder rather than `Rive`, while preserving the `AnimationHost` swap point
- next phase entrypoint: build the real settings screens and persistence flow so interval, duration, interaction mode, fullscreen behavior, and dismiss policy are editable from Flutter and reflected back into the native overlay

Phase Complete:
- phase: Phase 8: Settings UI And Persistence
- completed artifacts: replaced the in-memory settings store with a `shared_preferences`-backed repository; expanded the Flutter home screen into a usable settings panel for interval, duration, interaction mode, fullscreen behavior, dismiss policy, and early dismiss; saved settings now reload on startup and propagate back into the native overlay path.
- verification: `flutter test`; `flutter build macos`
- blockers: no manual restart validation was performed in this environment, though the persistence dependency was resolved and the app built successfully
- decision changes: persistence uses `shared_preferences` with the async API rather than an in-memory repository
- next phase entrypoint: add launch-at-login support and a clearer debug/status surface around current lifecycle, next trigger, last overlay result, and manual trigger behavior

Phase Complete:
- phase: Phase 9: Startup And Debugging
- completed artifacts: added a `LaunchAtStartupService` backed by `launch_at_startup` and `package_info_plus`; wired macOS login-item support through `LaunchAtLogin` in `MainFlutterWindow.swift` and the Xcode project; expanded the home screen into a clearer debug surface with manual trigger, recovery, pause/resume scheduling, launch-at-login toggle, and persistent last overlay result reporting.
- verification: `flutter test`; `flutter build macos`
- blockers: no manual end-to-end verification was possible for actual macOS login-item behavior after a real logout/login cycle
- decision changes: launch-at-login uses `launch_at_startup` on the Dart side with the native `LaunchAtLogin` Swift package on macOS
- next phase entrypoint: focus on repeated-session polish, timing cleanup, and release-hardening rather than new architecture

Phase Complete:
- phase: Phase 10: Polish And Release Readiness
- completed artifacts: removed dead scheduler state, added timer scheduler regression tests for repeated use and pause/resume timing, and refreshed `README.md` so repo docs match the shipped macOS architecture and verification flow.
- verification: `flutter test`; `flutter analyze`; `flutter build macos`
- blockers: no manual repeated-session or multi-monitor validation was possible in this environment
- decision changes: none
- next phase entrypoint: replace cat-specific overlay assumptions with a bundled media catalog model, then rebuild the settings and shell UX around transparent comic styling and update-driven content expansion

Phase Complete:
- phase: Phase 11: Media Catalog And Contract Refresh
- completed artifacts: added a typed `OverlayCatalogItem` model and `selectedOverlayId` selection flow across Dart persistence, UI, Pigeon, and Swift; introduced a centralized shipped-media source of truth for add/remove operations; updated settings UI with a media dropdown; changed runtime rendering so native macOS loads the selected Flutter `assetPath` directly from bundled `assets/` and infers image/video playback from the file extension instead of relying on a separately persisted format enum.
- verification: `dart run pigeon --input pigeons/overlay_api.dart --dart_out lib/platform/bridge/overlay_api.g.dart --swift_out macos/Runner/Overlay/overlay_api.g.swift`; `flutter test`; `flutter analyze`; `flutter build macos`
- blockers: no real media assets were added in this phase, so runtime playback still needs manual validation once bundled files exist
- decision changes: bundled overlay media now uses Flutter `assets/` as the packaging root and the selected `assetPath` as the runtime source of truth; the newer plan narrows the long-term macOS product path to native-supported video assets rather than mixed image/video support
- next phase entrypoint: replace the mixed HTML/WebKit media renderer with a native macOS media pipeline and tighten supported product formats around media that AppKit and AVFoundation handle cleanly

## Phase 12: Native macOS Media Pipeline
### Goal
Replace the current mixed HTML/WebKit media rendering path with native macOS video playback and lock the shipped media formats to ones that macOS supports well.

### Scope
- Remove WebKit/HTML as the primary overlay media renderer.
- Keep overlay windows native AppKit and render content with native macOS views/layers:
  - `AVPlayerLayer` or `AVPlayerView` for native video assets
- Narrow preferred bundled media formats to macOS-native-friendly formats such as:
  - `mov`
  - `mp4`
  - `m4v`
- Continue loading selected media from Flutter `assets/`.
- Ensure the overlay media fills the full screen bounds for each display.
- Update catalog/docs so product guidance no longer presents `webm` or image formats as primary macOS overlay formats.

### Deliverables
- Native macOS renderer no longer depends on `WKWebView` for the main supported video path.
- Full-screen media fitting behavior is implemented with native views/layers.
- Catalog and docs clearly describe that shipped overlay media is video-only on macOS.

### Verification
- `flutter test`
- `flutter analyze`
- `flutter build macos`
- manual validation with at least one native video asset

### Exit Criteria
- Selected Flutter asset path is rendered through native macOS media APIs.
- Overlay media occupies the full display-sized overlay surface.
- Product docs align with native-supported video-only guidance.

### Handoff Note Template
- native renderer classes changed
- supported media formats after the cut
- manual runtime results and any remaining fallback gaps

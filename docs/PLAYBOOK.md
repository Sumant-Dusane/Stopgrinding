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
- Current phase: Phase 9: Startup And Debugging

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

## Optional Phase 11: Windows Port
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

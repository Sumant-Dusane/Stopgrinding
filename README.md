# stopgrinding

`stopgrinding` is a macOS-first break overlay app built with Flutter for the app shell and native Swift/AppKit for the overlay engine.

## Current Status

- Phases 1 through 10 in `docs/PLAYBOOK.md` are implemented for the macOS path.
- Flutter owns scheduling, settings, and overlay orchestration.
- Native AppKit owns per-display windows, animation hosting, interaction strategy, and dismiss behavior.
- Windows remains an optional next phase behind the same typed Dart bridge.

## Docs

- Architecture and locked decisions: `docs/AGENTS.md`
- Phase plan and handoff history: `docs/PLAYBOOK.md`

## Verification

Run the standard checks from the repo root:

```bash
flutter test
flutter analyze
flutter build macos
```

## Repo Layout

- `lib/app`: app bootstrap and DI
- `lib/features/overlay`: overlay domain logic and presentation
- `lib/features/settings`: settings persistence and startup controls
- `lib/features/scheduler`: scheduling abstractions and timer behavior
- `lib/platform/bridge`: typed Flutter/native bridge via Pigeon
- `macos/Runner/Overlay`: native macOS overlay implementation

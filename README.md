# stopgrinding

`stopgrinding` is a macOS-first break overlay app built with Flutter for the app shell and native Swift/AppKit for the overlay engine.

## Current Status

- Phases 1 through 11 in `docs/PLAYBOOK.md` are implemented for the macOS path.
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

## Media Asset Flow

Bundled overlay media is loaded from Flutter `assets/`, with the selected
catalog entry's `assetPath` sent across the bridge and rendered by the native
macOS overlay pipeline.
The catalog remains the one-stop manifest for add/remove operations and
settings labels.

The default convention is:

```text
assets/
  overlays/
    catalog.json
    <overlay-id>/
      animation.<ext>
```

- `assets/overlays/catalog.json` is the one-stop catalog manifest for adding or removing shipped media entries.
- `<overlay-id>` must match the catalog id used in Flutter settings.
- `<ext>` should be a macOS-native-friendly video extension.
- Each manifest entry declares:
  - `id`
  - `title`
  - `assetPath`
- Adding or removing an overlay should usually mean:
  - update `assets/overlays/catalog.json`
  - add or remove the referenced media file
- Flutter now bundles the full `assets/` tree, so manifest entries can point to any shipped asset path under that root.
- Preferred macOS media formats are `mov`, `mp4`, and `m4v`.
- The planned steady-state macOS renderer is native AppKit/AVFoundation rather than HTML/WebKit.
- If a supported media file is missing, the native overlay falls back to a neutral placeholder card instead of a cat-specific asset.

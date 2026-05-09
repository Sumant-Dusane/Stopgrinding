# stopgrinding

`stopgrinding` is a macOS-first break overlay app built with Flutter for the app shell and native Swift/AppKit for the overlay engine.

## Current Status

- Phases 1 through 12 in `docs/PLAYBOOK.md` are implemented for the macOS path.
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

Bundled overlay videos are loaded from Flutter `assets/`, with the selected
shared Dart option's `assetPath` sent across the bridge and rendered by the
native macOS overlay pipeline.
The shared Dart video list remains the source of truth for settings labels and
selection options.

The default convention is:

```text
assets/
  overlays/
    <overlay-id>/
      <video-file>.<ext>
```

- `<overlay-id>` must match the catalog id used in Flutter settings.
- `<video-file>` can be any shipped asset filename referenced by the catalog entry.
- `<ext>` should be a macOS-native-friendly video extension.
- The shared video option list lives in [overlay_videos.dart](/Users/admin/Desktop/Personal/stopgrinding/lib/core/constants/overlay_videos.dart).
- Each Dart entry declares:
  - `id`
  - `title`
  - `assetPath`
  - `loopStart`
  - optional `loopEnd`
- Adding or removing an overlay should usually mean:
  - update `lib/core/constants/overlay_videos.dart`
  - add or remove the referenced media file
- Flutter now bundles the full `assets/` tree, so manifest entries can point to any shipped asset path under that root.
- Preferred macOS media formats are `mov`, `mp4`, and `m4v`.
- The planned steady-state macOS renderer is native AppKit/AVFoundation rather than HTML/WebKit.
- To keep the desktop visible behind the subject, the source video itself must include transparency, such as an alpha-capable HEVC `.mov`.
- The current macOS overlay renderer presents the media as a padded card anchored to the bottom-right of each display, with a right-to-left slide-in on show.
- Looping is configured from the Dart catalog's `loopStart` and `loopEnd`, and the native renderer treats that range as the steady-state loop segment after any non-looping intro.
- If a supported media file is missing, the native overlay falls back to a neutral placeholder card instead of a cat-specific asset.

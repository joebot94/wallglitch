# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

- Planned: add remaining real export effects (`Temporal Hold`).
- Planned: add HDR export pipeline (10-bit + color metadata path).
- Planned: add master-controller/text-app sync adapter for command intake in realtime mode.

## [v0.1.26] - 2026-03-12

- Added fixed titlebar compensation for the root editor stack to prevent top-toolbar drift under the macOS title bar after load workflows.
- Applied explicit top-edge safe-area handling (`ignoresSafeArea(.container, edges: .top)` + fixed offset) to stabilize toolbar visibility through `load_project` and `load_video` transitions.

## [v0.1.25] - 2026-03-12

- Rolled back top toolbar to a simpler pre-project-style single-row structure to eliminate persistent disappearing/cutoff behavior.
- Removed recent top-bar inset/two-row experiments that were causing instability after `load_project` and `load_video`.
- Kept project, queue, export, and grid commands available in the stable toolbar layout.

## [v0.1.24] - 2026-03-12

- Fixed top toolbar disappearing after load-project/load-video flows by anchoring toolbar in a `safeAreaInset(edge: .top)` container.
- Reintroduced horizontal scrolling only for the controls row (with leading alignment) to avoid overflow clipping while keeping interactions active.
- Kept status/project row pinned and stable under the controls row.

## [v0.1.23] - 2026-03-12

- Fixed toolbar collapse regression by removing strict row/container height clipping in the top bar.
- Added clearer A/B visibility:
  - compare mode now appears in queue rows and render lifecycle log lines (`render_queued`, `render_started`)
  - toolbar status row now displays active compare mode
  - effects panel clarifies that A/B currently applies to queued renders (live effected preview is future realtime work)

## [v0.1.22] - 2026-03-12

- Fixed non-responsive top-bar controls by removing the horizontal `ScrollView` wrapper from the primary controls row.
- Kept two-row toolbar structure but restored direct hit-testing on all top-row buttons/controls.

## [v0.1.21] - 2026-03-12

- Reworked top toolbar into a stable two-row layout to prevent disappearing controls when video state changes.
- Removed spacer-in-horizontal-scroll toolbar pattern that could scroll into blank regions after load/update events.
- Kept primary controls horizontally scrollable while pinning status/project metadata in a dedicated second row.

## [v0.1.20] - 2026-03-12

- Fixed intermittent top-toolbar disappearance by pinning toolbar height and clipping behavior.
- Refined bottom layout:
  - command log now occupies left/center bottom region
  - added dedicated bottom-right continuation column under the effects sidebar (`Render Queue`)
  - queue controls and queued-item removal are now available in that bottom-right panel

## [v0.1.19] - 2026-03-12

- Fixed top toolbar clipping/cutoff on narrower window widths and longer status text.
- Toolbar now uses horizontal scrolling with stable minimum layout width so controls remain accessible after load/save/render state changes.

## [v0.1.18] - 2026-03-12

- Added command-driven automation/keyframe system for effect parameters:
  - `set_automation_enabled`
  - `toggle_keyframe`
  - `set_lane_enabled`
  - `set_lane_mode`
  - `clear_lane`
  - `clear_all_automation`
- Added per-parameter automation controls in Effects panel:
  - `Add Key` / `Del Key` at current playhead time
  - lane enable checkbox
  - interpolation menu (`Hold`, `Linear`)
- Added global automation summary/toggle with keyframe count.
- Render pipeline now evaluates animated parameter values per frame during export.
- Project persistence now includes automation state and keyframe lanes (`.glitchlab` schema v2).

## [v0.1.17] - 2026-03-11

- Added command-driven project persistence:
  - `save_project`
  - `load_project`
  - `.glitchlab` JSON project format
- Added project save/load controls in toolbar.
- Added render queue system:
  - each render request is queued and auto-runs sequentially
  - queue inspection/removal in inspector
  - queue clear controls (`clear_render_queue`, `remove_render_queue_item`)
- Added A/B compare mode and solo effect controls:
  - `A: Original` bypasses all effects for queued renders
  - `B: FX` uses active effect stack
  - per-effect solo isolation via `set_solo_effect`

## [v0.1.16] - 2026-03-11

- Added command-driven export profile selection:
  - `H.264`
  - `HEVC`
  - `ProRes 422`
  - `ProRes 422 HQ`
- Added export profile picker in toolbar and profile display in inspector.
- Renderer now maps selected profile to codec/output settings and tags output filename with profile name.

## [v0.1.15] - 2026-03-11

- Added `Zone Swap` speed control parameter: `Change Rate` (Hz).
- `Change Rate` now controls how quickly swap pair layouts change over time.
- Updated Zone Swap presets to include `Change Rate` values.

## [v0.1.14] - 2026-03-11

- Added command-driven Effect Packs with bundled multi-effect configurations.
- Added effect pack catalog in sidebar:
  - `VHS Wreck`
  - `Swap Storm`
  - `Pixel Jolt`
  - `Soft Corrupt`
- Added active effect pack tracking in inspector (`Custom` when manually edited).

## [v0.1.13] - 2026-03-11

- Added `Zone Swap` presets in UI (`Subtle`, `Balanced`, `Heavy`, `Chaos`, `Custom`).
- Presets set both swap controls together (`swap_rate`, `pair_count`) for quick tuning.

## [v0.1.12] - 2026-03-11

- Added real `Zone Swap` export implementation with obvious tile-to-tile swaps.
- Wired `Zone Swap` to existing parameters (`swap_rate`, `pair_count`) and selected-zones behavior.
- Kept swap-pair work capped for stable performance on 4K and long clips.

## [v0.1.11] - 2026-03-11

- Added `Screen Tear` effect presets in UI (`Subtle`, `Balanced`, `Heavy`, `Brutal`, `Custom`) below sliders.
- Added real `Block Scramble` export implementation with zone-mask support.
- Kept `Block Scramble` iterations bounded for stable long/4K renders.

## [v0.1.10] - 2026-03-11

- Fixed `Screen Tear`/4K export stalls by interleaving audio sample writes during video rendering.
- Added timeout protection for writer readiness waits to prevent indefinite stuck progress states.
- Improved renderer failure behavior so deadlocks become explicit errors instead of frozen percentages.

## [v0.1.9] - 2026-03-11

- Fixed a render hang condition where writer readiness waits could stall indefinitely.
- Added failure-aware writer/reader readiness checks so render jobs fail fast instead of freezing.
- Optimized `Screen Tear` export effect for 4K stability and improved throughput.

## [v0.1.8] - 2026-03-11

- Added audio passthrough in offline exports.
- Added real export effect implementations for:
  - RGB Shift
  - Screen Tear
  - Pixel Drift
- Upgraded render effect chain to process multiple enabled effects in sequence.
- Added selected-zones-only masking support for each implemented real effect in export.

## [v0.1.6] - 2026-03-11

- Added real offline render pipeline (`AVAssetReader` -> `AVAssetWriter`).
- Added render progress and cancel flow (`render`, `cancel_render`).
- Added first real export effect path: Noise Corruption.
- Added selected-zones-only masking support for Noise Corruption in export.
- Added render status/progress UI in toolbar and inspector.

## [v0.1.5] - 2026-03-11

- Added command-driven timeline foundation (`seek`, `step_frame`).
- Added preview timeline controls (jump, frame step, scrub slider).
- Added FPS metadata loading and inspector timeline readout.

## [v0.1.4] - 2026-03-11

- Replaced zone preset dropdown with two-column preset browser popover.
- Added active-row highlighting for zone preset selection UI.

## [v0.1.3] - 2026-03-11

- Added zone selection preset system and resolver patterns.
- Added command-driven zone preset application (`apply_zone_preset`).
- Added toolbar preset selection and inspector zone preset status.

## [v0.1.2] - 2026-03-11

- Initial Milestone 1 foundation release.
- Added modular SwiftUI app structure and command processor architecture.
- Added grid/zone selection UX and effect model scaffolding.
- Added video metadata loading, preview surface, and command log panel.

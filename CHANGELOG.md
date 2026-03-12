# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

- Planned: add remaining real export effects (`Temporal Hold`).
- Planned: add export profile options (quality/bitrate presets).

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

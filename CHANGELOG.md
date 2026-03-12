# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

- Planned: add audio passthrough in offline renders.
- Planned: add additional real export effects (starting with RGB Shift).

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


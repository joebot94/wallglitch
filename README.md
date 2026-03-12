# GlitchLab (Milestone 1)

`GlitchLab` is a native macOS SwiftUI foundation for an offline 1080p glitch workflow with command-driven architecture.

Release history lives in [CHANGELOG.md](./CHANGELOG.md).

## What is implemented

- macOS SwiftUI app shell (`@main` app)
- Editor-style layout:
  - Top toolbar
  - Left inspector
  - Center preview + grid overlay
  - Right effects sidebar
  - Bottom command log
- Video file importer (`Open Video`)
- Video metadata loading (file name, resolution if available, duration if available, nominal FPS if available)
- Timeline foundation:
  - command-driven seek (`seek`)
  - frame stepping (`step_frame`)
  - preview scrubber with start/end and frame nudge controls
- Offline render job runner:
  - command-driven start/cancel (`render`, `cancel_render`)
  - in-app progress/status
  - export profile selection (`H.264`, `HEVC`, `ProRes 422`, `ProRes 422 HQ`)
  - source audio passthrough in export
  - output writes to `~/Documents/GlitchLabRenders` when output path is not supplied
- Real effect path in render pipeline:
  - `RGB Shift`, `Screen Tear`, `Pixel Drift`, `Zone Swap`, `Block Scramble`, and `Noise Corruption` are applied during export
  - selected-zones-only masking is supported for each implemented effect
- Clickable zone grid overlay with deterministic IDs (left-to-right, top-to-bottom)
- Grid presets: `2x2`, `3x3`, `4x4`, `8x8`, `16x16`
- Custom grid sizing controls for rows/cols (`1...16`)
- Zone selection preset two-column browser popover (All, 3x3, 2x2 Center, Corners, Cross+, X, diagonals, rows/cols, Outer Ring, Center 1, Custom)
- Zone selection actions: toggle, clear, select all
- Effect quick presets in UI:
  - Screen Tear: `Subtle`, `Balanced`, `Heavy`, `Brutal`, `Custom`
  - Zone Swap: `Subtle`, `Balanced`, `Heavy`, `Chaos`, `Custom`
  - Zone Swap includes `Change Rate` (Hz) to control how quickly swap patterns update over time
- Effect packs (command-driven):
  - `VHS Wreck`
  - `Swap Storm`
  - `Pixel Jolt`
  - `Soft Corrupt`
- Placeholder effect system with typed parameters for:
  - Temporal Hold
  - (other listed effects above are now real in export)
- Built-in preset examples
- In-app command log for all major actions
- Centralized command processing (`UI -> CommandProcessor -> AppState/Engine`)

## Placeholder in this milestone

- Additional real effect implementations (`Temporal Hold`)
- Metal/GPU acceleration and optimization pass
- Network/server control transport (the command model is ready, transport not added yet)

## Build and run

1. Open Terminal in this folder:

```bash
cd /Users/joe/Documents/GlitchLab
```

2. Build:

```bash
swift build
```

3. Run:

```bash
swift run
```

You can also open the package directly in Xcode (`File -> Open...`) and run it as a macOS app target.

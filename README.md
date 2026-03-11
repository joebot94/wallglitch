# GlitchLab (Milestone 1)

`GlitchLab` is a native macOS SwiftUI foundation for an offline 1080p glitch workflow with command-driven architecture.

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
- Clickable zone grid overlay with deterministic IDs (left-to-right, top-to-bottom)
- Grid presets: `2x2`, `3x3`, `4x4`, `8x8`, `16x16`
- Custom grid sizing controls for rows/cols (`1...16`)
- Zone selection preset two-column browser popover (All, 3x3, 2x2 Center, Corners, Cross+, X, diagonals, rows/cols, Outer Ring, Center 1, Custom)
- Zone selection actions: toggle, clear, select all
- Placeholder effect system with typed parameters for:
  - RGB Shift
  - Screen Tear
  - Pixel Drift
  - Zone Swap
  - Block Scramble
  - Temporal Hold
  - Noise Corruption
- Built-in preset examples
- In-app command log for all major actions
- Centralized command processing (`UI -> CommandProcessor -> AppState/Engine`)

## Placeholder in this milestone

- Actual glitch video processing/rendering pipeline
- Final export implementation (`render(...)` currently creates a placeholder render session + log entry)
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

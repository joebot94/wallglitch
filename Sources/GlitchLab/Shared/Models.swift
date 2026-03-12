import Foundation

enum GridPreset: String, CaseIterable, Identifiable {
    case twoByTwo = "2x2"
    case threeByThree = "3x3"
    case fourByFour = "4x4"
    case eightByEight = "8x8"
    case sixteenBySixteen = "16x16"

    var id: String { rawValue }

    var rows: Int {
        switch self {
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .eightByEight: return 8
        case .sixteenBySixteen: return 16
        }
    }

    var cols: Int { rows }

    static func matching(rows: Int, cols: Int) -> GridPreset? {
        allCases.first { $0.rows == rows && $0.cols == cols }
    }
}

enum ExportProfile: String, CaseIterable, Identifiable, Codable {
    case h264 = "H.264"
    case hevc = "HEVC"
    case proRes422 = "ProRes 422"
    case proRes422HQ = "ProRes 422 HQ"

    var id: String { rawValue }

    var commandName: String {
        switch self {
        case .h264: return "h264"
        case .hevc: return "hevc"
        case .proRes422: return "prores_422"
        case .proRes422HQ: return "prores_422_hq"
        }
    }
}

enum PreviewCompareMode: String, CaseIterable, Identifiable, Codable {
    case original = "A: Original"
    case effected = "B: FX"

    var id: String { rawValue }

    var commandName: String {
        switch self {
        case .original: return "original"
        case .effected: return "fx"
        }
    }
}

struct GridConfiguration: Equatable, Codable {
    var rows: Int
    var cols: Int

    static let `default` = GridConfiguration(rows: 4, cols: 4)

    var clamped: GridConfiguration {
        GridConfiguration(
            rows: min(max(rows, 1), 16),
            cols: min(max(cols, 1), 16)
        )
    }

    var zoneCount: Int { rows * cols }
    var label: String { "\(rows)x\(cols)" }
}

struct TimelineState: Equatable {
    var currentTimeSeconds: Double = 0
    var durationSeconds: Double = 0
    var nominalFPS: Double = 30

    var frameDuration: Double {
        1.0 / max(nominalFPS, 1.0)
    }

    var hasDuration: Bool {
        durationSeconds > 0
    }

    var clampedCurrentTime: Double {
        min(max(currentTimeSeconds, 0), max(durationSeconds, 0))
    }
}

enum RenderPhase: Equatable {
    case idle
    case preparing
    case running(progress: Double)
    case completed(outputURL: URL)
    case failed(message: String)
    case cancelled
}

struct RenderState: Equatable {
    var phase: RenderPhase = .idle

    var isRunning: Bool {
        switch phase {
        case .preparing, .running:
            return true
        default:
            return false
        }
    }

    var progress: Double {
        switch phase {
        case .running(let progress):
            return progress
        case .completed:
            return 1
        default:
            return 0
        }
    }

    var statusText: String {
        switch phase {
        case .idle:
            return "Idle"
        case .preparing:
            return "Preparing..."
        case .running(let progress):
            return String(format: "Rendering %.0f%%", progress * 100)
        case .completed(let outputURL):
            return "Done: \(outputURL.lastPathComponent)"
        case .failed(let message):
            return "Failed: \(message)"
        case .cancelled:
            return "Cancelled"
        }
    }
}

struct RenderQueueItem: Identifiable, Equatable {
    let id: UUID
    let enqueuedAt: Date
    let sourceURL: URL
    let outputURL: URL?
    let exportProfile: ExportProfile
    let effects: [EffectState]
    let grid: GridConfiguration
    let selectedZoneIDs: Set<Int>
    let compareMode: PreviewCompareMode
    let soloEffect: EffectType?

    var sourceName: String { sourceURL.lastPathComponent }
}

struct CommandLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

enum EffectType: String, CaseIterable, Identifiable, Codable {
    case rgbShift
    case screenTear
    case pixelDrift
    case zoneSwap
    case blockScramble
    case temporalHold
    case noiseCorruption

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rgbShift: return "RGB Shift"
        case .screenTear: return "Screen Tear"
        case .pixelDrift: return "Pixel Drift"
        case .zoneSwap: return "Zone Swap"
        case .blockScramble: return "Block Scramble"
        case .temporalHold: return "Temporal Hold"
        case .noiseCorruption: return "Noise Corruption"
        }
    }

    var commandName: String {
        switch self {
        case .rgbShift: return "RGBShift"
        case .screenTear: return "ScreenTear"
        case .pixelDrift: return "PixelDrift"
        case .zoneSwap: return "ZoneSwap"
        case .blockScramble: return "BlockScramble"
        case .temporalHold: return "TemporalHold"
        case .noiseCorruption: return "NoiseCorruption"
        }
    }
}

struct EffectParameter: Identifiable, Equatable, Codable {
    let id: String
    let label: String
    let minimum: Double
    let maximum: Double
    let step: Double
    let unit: String?
    var value: Double

    init(
        id: String,
        label: String,
        minimum: Double,
        maximum: Double,
        step: Double = 0.01,
        unit: String? = nil,
        value: Double
    ) {
        self.id = id
        self.label = label
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.unit = unit
        self.value = value
    }
}

struct EffectState: Identifiable, Equatable, Codable {
    let type: EffectType
    var isEnabled: Bool
    var selectedZonesOnly: Bool
    var parameters: [EffectParameter]

    var id: EffectType { type }
    var name: String { type.displayName }
}

enum AppCommand {
    case loadVideo(url: URL)
    case saveProject(url: URL)
    case loadProject(url: URL)
    case setGrid(rows: Int, cols: Int)
    case toggleZone(id: Int)
    case enableZone(id: Int)
    case disableZone(id: Int)
    case clearZones
    case selectAllZones
    case applyZonePreset(preset: ZoneSelectionPreset)
    case seek(seconds: Double)
    case stepFrame(delta: Int)
    case setExportProfile(profile: ExportProfile)
    case setEffectEnabled(effect: EffectType, enabled: Bool)
    case setEffectParameter(effect: EffectType, parameterID: String, value: Double)
    case setEffectTargetSelectedOnly(effect: EffectType, selectedOnly: Bool)
    case setCompareMode(mode: PreviewCompareMode)
    case setSoloEffect(effect: EffectType?)
    case applyEffectPack(name: String)
    case applyPreset(name: String)
    case render(outputURL: URL?)
    case cancelRender
    case clearRenderQueue
    case removeRenderQueueItem(id: UUID)
}

extension AppCommand {
    var logLine: String {
        switch self {
        case .loadVideo(let url):
            return "[CMD] load_video name=\(url.lastPathComponent)"
        case .saveProject(let url):
            return "[CMD] save_project file=\(url.lastPathComponent)"
        case .loadProject(let url):
            return "[CMD] load_project file=\(url.lastPathComponent)"
        case .setGrid(let rows, let cols):
            return "[CMD] set_grid rows=\(rows) cols=\(cols)"
        case .toggleZone(let id):
            return "[CMD] toggle_zone id=\(id)"
        case .enableZone(let id):
            return "[CMD] enable_zone id=\(id)"
        case .disableZone(let id):
            return "[CMD] disable_zone id=\(id)"
        case .clearZones:
            return "[CMD] clear_zones"
        case .selectAllZones:
            return "[CMD] select_all_zones"
        case .applyZonePreset(let preset):
            return "[CMD] apply_zone_preset name=\(preset.commandName)"
        case .seek(let seconds):
            return String(format: "[CMD] seek time=%.3f", seconds)
        case .stepFrame(let delta):
            return "[CMD] step_frame delta=\(delta)"
        case .setExportProfile(let profile):
            return "[CMD] set_export_profile name=\(profile.commandName)"
        case .setEffectEnabled(let effect, let enabled):
            return "[CMD] set_effect_enabled effect=\(effect.commandName) enabled=\(enabled)"
        case .setEffectParameter(let effect, let parameterID, let value):
            return "[CMD] set_effect_parameter effect=\(effect.commandName) parameter=\(parameterID) value=\(value)"
        case .setEffectTargetSelectedOnly(let effect, let selectedOnly):
            return "[CMD] set_effect_target effect=\(effect.commandName) selected_only=\(selectedOnly)"
        case .setCompareMode(let mode):
            return "[CMD] set_compare_mode mode=\(mode.commandName)"
        case .setSoloEffect(let effect):
            if let effect {
                return "[CMD] set_solo_effect effect=\(effect.commandName)"
            }
            return "[CMD] clear_solo_effect"
        case .applyEffectPack(let name):
            return "[CMD] apply_effect_pack name=\(name)"
        case .applyPreset(let name):
            return "[CMD] apply_preset name=\(name)"
        case .render(let outputURL):
            if let outputURL {
                return "[CMD] render output=\(outputURL.lastPathComponent)"
            }
            return "[CMD] render output=auto"
        case .cancelRender:
            return "[CMD] cancel_render"
        case .clearRenderQueue:
            return "[CMD] clear_render_queue"
        case .removeRenderQueueItem(let id):
            return "[CMD] remove_render_queue_item id=\(id.uuidString)"
        }
    }
}

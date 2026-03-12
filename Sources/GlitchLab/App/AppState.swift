import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var projectName: String = "GlitchLab Session"
    @Published var activePresetName: String = "Manual"
    @Published var activeEffectPackName: String = "Custom"
    @Published var projectURL: URL?
    @Published var exportProfile: ExportProfile = .h264
    @Published var compareMode: PreviewCompareMode = .effected
    @Published var soloEffect: EffectType?
    @Published var automationEnabled: Bool = true
    @Published var automationLanes: [ParameterAutomationLane] = []
    @Published var videoURL: URL?
    @Published var videoInfo: VideoAssetInfo?
    @Published var timeline: TimelineState = TimelineState()
    @Published var renderState: RenderState = RenderState()
    @Published var renderQueue: [RenderQueueItem] = []
    @Published var activeRenderJob: RenderQueueItem?
    @Published var gridConfiguration: GridConfiguration = .default
    @Published var zoneSelection: ZoneSelectionModel = ZoneSelectionModel()
    @Published var activeZonePreset: ZoneSelectionPreset = .custom
    @Published var effects: [EffectState] = DefaultEffectCatalog.makeDefaultEffects()
    @Published var commandLog: [CommandLogEntry] = [
        CommandLogEntry(timestamp: Date(), message: "[SYS] GlitchLab initialized")
    ]

    var selectedZoneCount: Int {
        zoneSelection.selectedZoneIDs.count
    }

    var queuedRenderCount: Int {
        renderQueue.count
    }

    var gridPreset: GridPreset? {
        GridPreset.matching(rows: gridConfiguration.rows, cols: gridConfiguration.cols)
    }

    var effectiveEffectsBypassed: Bool {
        compareMode == .original
    }

    var effectiveEffects: [EffectState] {
        if effectiveEffectsBypassed {
            return effects.map { effect in
                var copy = effect
                copy.isEnabled = false
                return copy
            }
        }
        guard let soloEffect else {
            return effects
        }
        return effects.map { effect in
            var copy = effect
            if copy.type != soloEffect {
                copy.isEnabled = false
            }
            return copy
        }
    }

    var totalAutomationKeyframeCount: Int {
        automationLanes.reduce(0) { partial, lane in
            partial + lane.keyframes.count
        }
    }

    func appendLog(_ message: String) {
        commandLog.append(CommandLogEntry(timestamp: Date(), message: message))
        if commandLog.count > 1000 {
            commandLog.removeFirst(commandLog.count - 1000)
        }
    }

    func effectState(for type: EffectType) -> EffectState? {
        effects.first(where: { $0.type == type })
    }

    func automationLane(effect: EffectType, parameterID: String) -> ParameterAutomationLane? {
        automationLanes.first {
            $0.effect == effect && $0.parameterID == parameterID
        }
    }
}

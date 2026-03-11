import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var projectName: String = "GlitchLab Session"
    @Published var activePresetName: String = "Manual"
    @Published var videoURL: URL?
    @Published var videoInfo: VideoAssetInfo?
    @Published var timeline: TimelineState = TimelineState()
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

    var gridPreset: GridPreset? {
        GridPreset.matching(rows: gridConfiguration.rows, cols: gridConfiguration.cols)
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
}

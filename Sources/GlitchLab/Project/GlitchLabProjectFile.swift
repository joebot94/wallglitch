import Foundation

struct GlitchLabProjectFile: Codable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int = GlitchLabProjectFile.currentSchemaVersion
    var savedAt: Date = Date()
    var projectName: String
    var activePresetName: String
    var activeEffectPackName: String
    var exportProfile: ExportProfile
    var compareMode: PreviewCompareMode
    var soloEffect: EffectType?
    var automationEnabled: Bool = true
    var automationLanes: [ParameterAutomationLane] = []
    var videoPath: String?
    var gridConfiguration: GridConfiguration
    var selectedZoneIDs: [Int]
    var activeZonePreset: ZoneSelectionPreset
    var effects: [EffectState]
}

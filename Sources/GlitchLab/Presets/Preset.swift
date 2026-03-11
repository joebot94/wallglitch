import Foundation

struct Preset: Identifiable {
    let id = UUID()
    let name: String
    let grid: GridConfiguration
    let selectedZoneIDs: [Int]
    let effectSettings: [EffectPresetSetting]
}

struct EffectPresetSetting {
    let effect: EffectType
    let enabled: Bool
    let selectedZonesOnly: Bool
    let parameterValues: [String: Double]
}

import Foundation

struct EffectPack: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let effectSettings: [EffectPresetSetting]
}

import Foundation

struct PresetStore {
    let presets: [Preset] = [
        Preset(
            name: "Sparse RGB Grid",
            grid: GridConfiguration(rows: 4, cols: 4),
            selectedZoneIDs: [1, 3, 6, 8, 11, 14],
            effectSettings: [
                EffectPresetSetting(
                    effect: .rgbShift,
                    enabled: true,
                    selectedZonesOnly: true,
                    parameterValues: ["amount": 0.45, "angle": 12.0]
                )
            ]
        ),
        Preset(
            name: "Dense Noise Sweep",
            grid: GridConfiguration(rows: 8, cols: 8),
            selectedZoneIDs: Array(1...64),
            effectSettings: [
                EffectPresetSetting(
                    effect: .noiseCorruption,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["noise": 0.55, "seed_drift": 0.3]
                ),
                EffectPresetSetting(
                    effect: .temporalHold,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["hold_frames": 3.0, "blend": 0.4]
                )
            ]
        )
    ]

    func preset(named name: String) -> Preset? {
        presets.first { $0.name == name }
    }
}

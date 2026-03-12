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

    let effectPacks: [EffectPack] = [
        EffectPack(
            name: "VHS Wreck",
            description: "Analog tear + channel split + hiss.",
            effectSettings: [
                EffectPresetSetting(
                    effect: .screenTear,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["intensity": 0.58, "line_count": 8]
                ),
                EffectPresetSetting(
                    effect: .rgbShift,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["amount": 0.32, "angle": 13]
                ),
                EffectPresetSetting(
                    effect: .noiseCorruption,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["noise": 0.2, "seed_drift": 0.1]
                )
            ]
        ),
        EffectPack(
            name: "Swap Storm",
            description: "Aggressive zone swaps with scramble.",
            effectSettings: [
                EffectPresetSetting(
                    effect: .zoneSwap,
                    enabled: true,
                    selectedZonesOnly: true,
                    parameterValues: ["swap_rate": 0.85, "pair_count": 10, "change_rate": 8]
                ),
                EffectPresetSetting(
                    effect: .blockScramble,
                    enabled: true,
                    selectedZonesOnly: true,
                    parameterValues: ["amount": 0.55, "iterations": 5]
                ),
                EffectPresetSetting(
                    effect: .screenTear,
                    enabled: true,
                    selectedZonesOnly: true,
                    parameterValues: ["intensity": 0.35, "line_count": 10]
                )
            ]
        ),
        EffectPack(
            name: "Pixel Jolt",
            description: "Chunky pixel drift with hard displacement.",
            effectSettings: [
                EffectPresetSetting(
                    effect: .pixelDrift,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["drift": 0.62, "block_size": 18]
                ),
                EffectPresetSetting(
                    effect: .blockScramble,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["amount": 0.35, "iterations": 3]
                )
            ]
        ),
        EffectPack(
            name: "Soft Corrupt",
            description: "Subtle corruption pass for texture.",
            effectSettings: [
                EffectPresetSetting(
                    effect: .noiseCorruption,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["noise": 0.12, "seed_drift": 0.08]
                ),
                EffectPresetSetting(
                    effect: .rgbShift,
                    enabled: true,
                    selectedZonesOnly: false,
                    parameterValues: ["amount": 0.16, "angle": 7]
                )
            ]
        )
    ]

    func preset(named name: String) -> Preset? {
        presets.first { $0.name == name }
    }

    func effectPack(named name: String) -> EffectPack? {
        effectPacks.first { $0.name == name }
    }
}

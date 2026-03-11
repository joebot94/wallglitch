import Foundation

struct NoiseCorruptionEffect: GlitchEffectDefinition {
    static let type: EffectType = .noiseCorruption

    static func makeDefaultState() -> EffectState {
        EffectState(
            type: type,
            isEnabled: false,
            selectedZonesOnly: false,
            parameters: [
                EffectParameter(
                    id: "noise",
                    label: "Noise",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.2
                ),
                EffectParameter(
                    id: "seed_drift",
                    label: "Seed Drift",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.15
                )
            ]
        )
    }
}

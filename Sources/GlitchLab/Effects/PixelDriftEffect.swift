import Foundation

struct PixelDriftEffect: GlitchEffectDefinition {
    static let type: EffectType = .pixelDrift

    static func makeDefaultState() -> EffectState {
        EffectState(
            type: type,
            isEnabled: false,
            selectedZonesOnly: false,
            parameters: [
                EffectParameter(
                    id: "drift",
                    label: "Drift",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.3
                ),
                EffectParameter(
                    id: "block_size",
                    label: "Block Size",
                    minimum: 1.0,
                    maximum: 64.0,
                    step: 1.0,
                    value: 12.0
                )
            ]
        )
    }
}

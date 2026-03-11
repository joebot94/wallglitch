import Foundation

struct TemporalHoldEffect: GlitchEffectDefinition {
    static let type: EffectType = .temporalHold

    static func makeDefaultState() -> EffectState {
        EffectState(
            type: type,
            isEnabled: false,
            selectedZonesOnly: false,
            parameters: [
                EffectParameter(
                    id: "hold_frames",
                    label: "Hold Frames",
                    minimum: 1.0,
                    maximum: 24.0,
                    step: 1.0,
                    value: 4.0
                ),
                EffectParameter(
                    id: "blend",
                    label: "Blend",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.5
                )
            ]
        )
    }
}

import Foundation

struct BlockScrambleEffect: GlitchEffectDefinition {
    static let type: EffectType = .blockScramble

    static func makeDefaultState() -> EffectState {
        EffectState(
            type: type,
            isEnabled: false,
            selectedZonesOnly: true,
            parameters: [
                EffectParameter(
                    id: "amount",
                    label: "Amount",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.25
                ),
                EffectParameter(
                    id: "iterations",
                    label: "Iterations",
                    minimum: 1.0,
                    maximum: 16.0,
                    step: 1.0,
                    value: 3.0
                )
            ]
        )
    }
}

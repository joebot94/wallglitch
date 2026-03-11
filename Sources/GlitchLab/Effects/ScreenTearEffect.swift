import Foundation

struct ScreenTearEffect: GlitchEffectDefinition {
    static let type: EffectType = .screenTear

    static func makeDefaultState() -> EffectState {
        EffectState(
            type: type,
            isEnabled: false,
            selectedZonesOnly: false,
            parameters: [
                EffectParameter(
                    id: "intensity",
                    label: "Intensity",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.4
                ),
                EffectParameter(
                    id: "line_count",
                    label: "Lines",
                    minimum: 1.0,
                    maximum: 64.0,
                    step: 1.0,
                    value: 8.0
                )
            ]
        )
    }
}

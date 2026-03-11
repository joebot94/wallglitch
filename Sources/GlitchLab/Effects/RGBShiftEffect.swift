import Foundation

struct RGBShiftEffect: GlitchEffectDefinition {
    static let type: EffectType = .rgbShift

    static func makeDefaultState() -> EffectState {
        EffectState(
            type: type,
            isEnabled: false,
            selectedZonesOnly: false,
            parameters: [
                EffectParameter(
                    id: "amount",
                    label: "Amount",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.35
                ),
                EffectParameter(
                    id: "angle",
                    label: "Angle",
                    minimum: 0.0,
                    maximum: 360.0,
                    step: 1.0,
                    unit: "deg",
                    value: 16.0
                )
            ]
        )
    }
}

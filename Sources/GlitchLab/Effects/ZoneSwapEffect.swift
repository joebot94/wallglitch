import Foundation

struct ZoneSwapEffect: GlitchEffectDefinition {
    static let type: EffectType = .zoneSwap

    static func makeDefaultState() -> EffectState {
        EffectState(
            type: type,
            isEnabled: false,
            selectedZonesOnly: true,
            parameters: [
                EffectParameter(
                    id: "swap_rate",
                    label: "Swap Rate",
                    minimum: 0.0,
                    maximum: 1.0,
                    step: 0.01,
                    value: 0.5
                ),
                EffectParameter(
                    id: "pair_count",
                    label: "Pairs",
                    minimum: 1.0,
                    maximum: 64.0,
                    step: 1.0,
                    value: 4.0
                ),
                EffectParameter(
                    id: "change_rate",
                    label: "Change Rate",
                    minimum: 0.25,
                    maximum: 60.0,
                    step: 0.25,
                    unit: "Hz",
                    value: 8.0
                )
            ]
        )
    }
}

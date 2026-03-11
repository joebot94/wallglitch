import Foundation

protocol GlitchEffectDefinition {
    static var type: EffectType { get }
    static func makeDefaultState() -> EffectState
}

enum DefaultEffectCatalog {
    static func makeDefaultEffects() -> [EffectState] {
        [
            RGBShiftEffect.makeDefaultState(),
            ScreenTearEffect.makeDefaultState(),
            PixelDriftEffect.makeDefaultState(),
            ZoneSwapEffect.makeDefaultState(),
            BlockScrambleEffect.makeDefaultState(),
            TemporalHoldEffect.makeDefaultState(),
            NoiseCorruptionEffect.makeDefaultState()
        ]
    }
}

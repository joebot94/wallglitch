import SwiftUI

struct EffectsPanel: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Effects")
                    .font(.headline)

                ForEach(EffectType.allCases) { effectType in
                    if let effect = appState.effectState(for: effectType) {
                        effectCard(effect)
                    }
                }
            }
            .padding(12)
        }
    }

    private func effectCard(_ effect: EffectState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(effect.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { appState.effectState(for: effect.type)?.isEnabled ?? false },
                        set: { value in
                            commandProcessor.process(.setEffectEnabled(effect: effect.type, enabled: value))
                        }
                    )
                )
                .toggleStyle(.switch)
                .labelsHidden()
            }

            Toggle(
                "Selected Zones Only",
                isOn: Binding(
                    get: { appState.effectState(for: effect.type)?.selectedZonesOnly ?? false },
                    set: { value in
                        commandProcessor.process(
                            .setEffectTargetSelectedOnly(effect: effect.type, selectedOnly: value)
                        )
                    }
                )
            )
            .font(.caption)

            ForEach(effect.parameters) { parameter in
                let value = appState.effectState(for: effect.type)?
                    .parameters
                    .first(where: { $0.id == parameter.id })?
                    .value ?? parameter.value

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(parameter.label)
                            .font(.caption)
                        Spacer()
                        Text(AppFormatters.parameterString(value: value, step: parameter.step, unit: parameter.unit))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: {
                                appState.effectState(for: effect.type)?
                                    .parameters
                                    .first(where: { $0.id == parameter.id })?
                                    .value ?? parameter.value
                            },
                            set: { newValue in
                                commandProcessor.process(
                                    .setEffectParameter(
                                        effect: effect.type,
                                        parameterID: parameter.id,
                                        value: newValue
                                    )
                                )
                            }
                        ),
                        in: parameter.minimum...parameter.maximum,
                        step: parameter.step
                    )
                }
            }

            if effect.type == .screenTear {
                screenTearPresetControl(effect: effect)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func screenTearPresetControl(effect: EffectState) -> some View {
        let intensity = parameterValue(effect: effect, id: "intensity", fallback: 0.4)
        let lines = parameterValue(effect: effect, id: "line_count", fallback: 8)
        let activePreset = ScreenTearPreset.matching(intensity: intensity, lines: lines)

        return HStack(spacing: 8) {
            Text("Tear Preset")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(
                "",
                selection: Binding(
                    get: { activePreset },
                    set: { preset in
                        guard preset != .custom else { return }
                        commandProcessor.process(
                            .setEffectParameter(
                                effect: effect.type,
                                parameterID: "intensity",
                                value: preset.intensity
                            )
                        )
                        commandProcessor.process(
                            .setEffectParameter(
                                effect: effect.type,
                                parameterID: "line_count",
                                value: preset.lines
                            )
                        )
                    }
                )
            ) {
                ForEach(ScreenTearPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private func parameterValue(effect: EffectState, id: String, fallback: Double) -> Double {
        appState.effectState(for: effect.type)?
            .parameters
            .first(where: { $0.id == id })?
            .value ?? fallback
    }
}

private enum ScreenTearPreset: String, CaseIterable, Identifiable {
    case subtle = "Subtle"
    case balanced = "Balanced"
    case heavy = "Heavy"
    case brutal = "Brutal"
    case custom = "Custom"

    var id: String { rawValue }

    var intensity: Double {
        switch self {
        case .subtle: return 0.2
        case .balanced: return 0.4
        case .heavy: return 0.65
        case .brutal: return 0.9
        case .custom: return 0.4
        }
    }

    var lines: Double {
        switch self {
        case .subtle: return 20
        case .balanced: return 10
        case .heavy: return 6
        case .brutal: return 3
        case .custom: return 8
        }
    }

    static func matching(intensity: Double, lines: Double) -> ScreenTearPreset {
        let presets = allCases.filter { $0 != .custom }
        if let exact = presets.first(where: {
            abs($0.intensity - intensity) < 0.03 && abs($0.lines - lines) < 0.6
        }) {
            return exact
        }
        return .custom
    }
}

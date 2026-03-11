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
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

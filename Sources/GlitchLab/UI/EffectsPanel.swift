import SwiftUI

struct EffectsPanel: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Effects")
                    .font(.headline)

                compareControls

                ForEach(EffectType.allCases) { effectType in
                    if let effect = appState.effectState(for: effectType) {
                        effectCard(effect)
                    }
                }
            }
            .padding(12)
        }
    }

    private var compareControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A/B Compare")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(
                "A/B Compare",
                selection: Binding(
                    get: { appState.compareMode },
                    set: { mode in
                        commandProcessor.process(.setCompareMode(mode: mode))
                    }
                )
            ) {
                ForEach(PreviewCompareMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Solo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let soloEffect = appState.soloEffect {
                    Text(soloEffect.displayName)
                        .font(.caption)
                    Button("Clear") {
                        commandProcessor.process(.setSoloEffect(effect: nil))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Text("Off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Toggle(
                    "Automation",
                    isOn: Binding(
                        get: { appState.automationEnabled },
                        set: { enabled in
                            commandProcessor.process(.setAutomationEnabled(enabled))
                        }
                    )
                )
                .font(.caption)

                Spacer()

                Text("Keyframes \(appState.totalAutomationKeyframeCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if appState.totalAutomationKeyframeCount > 0 {
                    Button("Clear") {
                        commandProcessor.process(.clearAllAutomation)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func effectCard(_ effect: EffectState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(effect.name)
                    .font(.subheadline.weight(.semibold))

                if appState.soloEffect == effect.type {
                    Text("SOLO")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }

                Spacer()

                Button(appState.soloEffect == effect.type ? "Unsolo" : "Solo") {
                    let target: EffectType? = (appState.soloEffect == effect.type) ? nil : effect.type
                    commandProcessor.process(.setSoloEffect(effect: target))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

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

                    automationRow(effect: effect, parameter: parameter, currentValue: value)
                }
            }

            if effect.type == .screenTear {
                screenTearPresetControl(effect: effect)
            }
            if effect.type == .zoneSwap {
                zoneSwapPresetControl(effect: effect)
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

    private func zoneSwapPresetControl(effect: EffectState) -> some View {
        let rate = parameterValue(effect: effect, id: "swap_rate", fallback: 0.5)
        let pairCount = parameterValue(effect: effect, id: "pair_count", fallback: 4)
        let changeRate = parameterValue(effect: effect, id: "change_rate", fallback: 8)
        let activePreset = ZoneSwapPreset.matching(rate: rate, pairCount: pairCount, changeRate: changeRate)

        return HStack(spacing: 8) {
            Text("Swap Preset")
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
                                parameterID: "swap_rate",
                                value: preset.rate
                            )
                        )
                        commandProcessor.process(
                            .setEffectParameter(
                                effect: effect.type,
                                parameterID: "pair_count",
                                value: preset.pairCount
                            )
                        )
                        commandProcessor.process(
                            .setEffectParameter(
                                effect: effect.type,
                                parameterID: "change_rate",
                                value: preset.changeRate
                            )
                        )
                    }
                )
            ) {
                ForEach(ZoneSwapPreset.allCases) { preset in
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

    private func automationRow(
        effect: EffectState,
        parameter: EffectParameter,
        currentValue: Double
    ) -> some View {
        let lane = appState.automationLane(effect: effect.type, parameterID: parameter.id)
        let hasKeyframe = laneHasKeyframeAtPlayhead(lane)

        return HStack(spacing: 8) {
            Button(hasKeyframe ? "Del Key" : "Add Key") {
                commandProcessor.process(
                    .toggleAutomationKeyframe(
                        effect: effect.type,
                        parameterID: parameter.id,
                        timeSeconds: appState.timeline.currentTimeSeconds,
                        value: currentValue
                    )
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Toggle(
                "Lane",
                isOn: Binding(
                    get: { lane?.isEnabled ?? false },
                    set: { enabled in
                        commandProcessor.process(
                            .setAutomationLaneEnabled(
                                effect: effect.type,
                                parameterID: parameter.id,
                                enabled: enabled
                            )
                        )
                    }
                )
            )
            .toggleStyle(.checkbox)
            .font(.caption2)

            Picker(
                "",
                selection: Binding(
                    get: { lane?.interpolation ?? .linear },
                    set: { mode in
                        commandProcessor.process(
                            .setAutomationInterpolation(
                                effect: effect.type,
                                parameterID: parameter.id,
                                mode: mode
                            )
                        )
                    }
                )
            ) {
                ForEach(AutomationInterpolation.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(lane == nil)

            Spacer()

            Text("KF \(lane?.keyframes.count ?? 0)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func laneHasKeyframeAtPlayhead(_ lane: ParameterAutomationLane?) -> Bool {
        guard let lane else { return false }
        let playhead = appState.timeline.currentTimeSeconds
        let epsilon = max(0.0005, appState.timeline.frameDuration * 0.45)
        return lane.keyframes.contains { abs($0.timeSeconds - playhead) <= epsilon }
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

private enum ZoneSwapPreset: String, CaseIterable, Identifiable {
    case subtle = "Subtle"
    case balanced = "Balanced"
    case heavy = "Heavy"
    case chaos = "Chaos"
    case custom = "Custom"

    var id: String { rawValue }

    var rate: Double {
        switch self {
        case .subtle: return 0.2
        case .balanced: return 0.5
        case .heavy: return 0.75
        case .chaos: return 1.0
        case .custom: return 0.5
        }
    }

    var pairCount: Double {
        switch self {
        case .subtle: return 2
        case .balanced: return 4
        case .heavy: return 8
        case .chaos: return 12
        case .custom: return 4
        }
    }

    var changeRate: Double {
        switch self {
        case .subtle: return 1.5
        case .balanced: return 4
        case .heavy: return 8
        case .chaos: return 16
        case .custom: return 8
        }
    }

    static func matching(rate: Double, pairCount: Double, changeRate: Double) -> ZoneSwapPreset {
        let presets = allCases.filter { $0 != .custom }
        if let exact = presets.first(where: {
            abs($0.rate - rate) < 0.03 &&
            abs($0.pairCount - pairCount) < 0.6 &&
            abs($0.changeRate - changeRate) < 0.35
        }) {
            return exact
        }
        return .custom
    }
}

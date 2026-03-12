import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var commandProcessor: CommandProcessor

    private let presetStore = PresetStore()

    var body: some View {
        VStack(spacing: 0) {
            EffectsPanel()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Effect Packs")
                    .font(.headline)
                ForEach(presetStore.effectPacks) { pack in
                    Button {
                        commandProcessor.process(.applyEffectPack(name: pack.name))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name)
                            Text(pack.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(12)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.headline)
                ForEach(presetStore.presets) { preset in
                    Button(preset.name) {
                        commandProcessor.process(.applyPreset(name: preset.name))
                    }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
    }
}

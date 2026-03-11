import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var commandProcessor: CommandProcessor

    private let presetStore = PresetStore()

    var body: some View {
        VStack(spacing: 0) {
            EffectsPanel()

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

import SwiftUI

struct ZonePresetBrowserView: View {
    let activePreset: ZoneSelectionPreset
    let onSelect: (ZoneSelectionPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(ZoneSelectionPreset.browserColumns.enumerated()), id: \.offset) { _, column in
                    VStack(spacing: 4) {
                        ForEach(column) { preset in
                            Button {
                                onSelect(preset)
                            } label: {
                                HStack {
                                    Text(preset.rawValue)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    Spacer()
                                    if preset == activePreset {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .foregroundStyle(preset == activePreset ? Color.black : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(preset == activePreset ? Color.orange : Color.secondary.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(10)
        .frame(width: 520)
    }
}

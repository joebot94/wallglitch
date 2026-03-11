import SwiftUI

struct InspectorPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Project")
                .font(.headline)

            LabeledContent("Name", value: appState.projectName)
            LabeledContent("Preset", value: appState.activePresetName)

            Divider()

            Text("Video")
                .font(.headline)

            if let info = appState.videoInfo {
                LabeledContent("File", value: info.fileName)
                    .lineLimit(2)
                LabeledContent("Resolution", value: info.resolutionText)
                LabeledContent("Duration", value: info.durationText)
                LabeledContent("FPS", value: info.fpsText)
                LabeledContent(
                    "Playhead",
                    value: "\(AppFormatters.durationString(seconds: appState.timeline.currentTimeSeconds)) / \(AppFormatters.durationString(seconds: appState.timeline.durationSeconds))"
                )
            } else {
                Text("No video selected")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Grid")
                .font(.headline)

            LabeledContent("Size", value: appState.gridConfiguration.label)
            LabeledContent("Zone Preset", value: appState.activeZonePreset.rawValue)
            LabeledContent("Selected", value: "\(appState.selectedZoneCount) / \(appState.gridConfiguration.zoneCount)")

            Text("Selected Zone IDs")
                .font(.subheadline.weight(.semibold))

            ScrollView {
                if appState.zoneSelection.sortedIDs.isEmpty {
                    Text("None")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                } else {
                    Text(appState.zoneSelection.sortedIDs.map(String.init).joined(separator: ", "))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 120)
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

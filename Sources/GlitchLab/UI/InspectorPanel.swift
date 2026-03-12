import SwiftUI

struct InspectorPanel: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Project")
                .font(.headline)

            LabeledContent("Name", value: appState.projectName)
            LabeledContent("Preset", value: appState.activePresetName)
            LabeledContent("Effect Pack", value: appState.activeEffectPackName)

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
            .frame(minHeight: 100)
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            Text("Render")
                .font(.headline)
            LabeledContent("Profile", value: appState.exportProfile.rawValue)
            LabeledContent("Compare", value: appState.compareMode.rawValue)
            LabeledContent("Solo", value: appState.soloEffect?.displayName ?? "Off")
            LabeledContent("Automation", value: appState.automationEnabled ? "On" : "Off")
            LabeledContent("Keyframes", value: "\(appState.totalAutomationKeyframeCount)")
            LabeledContent("Status", value: appState.renderState.statusText)
            if let activeRenderJob = appState.activeRenderJob {
                LabeledContent("Now Rendering", value: activeRenderJob.sourceName)
                    .lineLimit(2)
            }
            if appState.renderState.isRunning {
                ProgressView(value: appState.renderState.progress)
            }

            if !appState.renderQueue.isEmpty {
                Text("Queue")
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(appState.renderQueue) { item in
                            HStack(alignment: .top, spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.sourceName)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(item.exportProfile.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Button {
                                    commandProcessor.process(.removeRenderQueueItem(id: item.id))
                                } label: {
                                    Image(systemName: "xmark.circle")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(6)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(minHeight: 70, maxHeight: 150)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

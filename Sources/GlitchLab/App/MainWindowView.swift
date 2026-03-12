import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                InspectorPanel()
                    .frame(width: 250)

                Divider()

                PreviewPane()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                SidebarView()
                    .frame(width: 360)
            }

            Divider()

            HStack(spacing: 0) {
                LogPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                BottomRightPanel()
                    .frame(width: 360)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 190)
        }
        .toolbar {
            nativeToolbarContent
        }
    }

    @ToolbarContentBuilder
    private var nativeToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button("Open Video") {
                openVideoPanel()
            }

            Button("Load Project") {
                openProjectPanel()
            }

            Button("Save Project") {
                saveProjectPanel()
            }
        }

        ToolbarItemGroup(placement: .automatic) {
            Menu {
                ForEach(GridPreset.allCases) { preset in
                    Button(preset.rawValue) {
                        commandProcessor.process(.setGrid(rows: preset.rows, cols: preset.cols))
                    }
                }

                Divider()

                Text("Custom: \(appState.gridConfiguration.label)")
            } label: {
                Text(gridToolbarTitle)
                    .frame(width: 88, alignment: .leading)
            }

            Menu {
                ForEach(1...16, id: \.self) { row in
                    Button("Rows \(row)") {
                        commandProcessor.process(
                            .setGrid(rows: row, cols: appState.gridConfiguration.cols)
                        )
                    }
                }
            } label: {
                Text("Rows \(appState.gridConfiguration.rows)")
                    .frame(width: 68, alignment: .leading)
            }

            Menu {
                ForEach(1...16, id: \.self) { col in
                    Button("Cols \(col)") {
                        commandProcessor.process(
                            .setGrid(rows: appState.gridConfiguration.rows, cols: col)
                        )
                    }
                }
            } label: {
                Text("Cols \(appState.gridConfiguration.cols)")
                    .frame(width: 68, alignment: .leading)
            }

            Menu {
                ForEach(ZoneSelectionPreset.allCases) { preset in
                    Button(preset.rawValue) {
                        commandProcessor.process(.applyZonePreset(preset: preset))
                    }
                }
            } label: {
                Text(zoneToolbarTitle)
                    .frame(width: 90, alignment: .leading)
            }

            Button("Clear Zones") {
                commandProcessor.process(.clearZones)
            }

            Button("Select All") {
                commandProcessor.process(.selectAllZones)
            }
        }

        ToolbarItemGroup(placement: .automatic) {
            Picker(
                "Export",
                selection: Binding(
                    get: { appState.exportProfile },
                    set: { profile in
                        commandProcessor.process(.setExportProfile(profile: profile))
                    }
                )
            ) {
                ForEach(ExportProfile.allCases) { profile in
                    Text(profile.rawValue).tag(profile)
                }
            }
            .frame(width: 110)

            Button(appState.renderState.isRunning ? "Cancel Render" : "Queue Render") {
                if appState.renderState.isRunning {
                    commandProcessor.process(.cancelRender)
                } else {
                    commandProcessor.process(.render(outputURL: nil))
                }
            }
            .disabled(!appState.renderState.isRunning && appState.videoURL == nil)
        }

        ToolbarItem(placement: .status) {
            HStack(spacing: 8) {
                Text(appState.renderState.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if appState.queuedRenderCount > 0 {
                    Text("Queue \(appState.queuedRenderCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        ToolbarItem(placement: .principal) {
            VStack(alignment: .leading, spacing: 1) {
                Text(appState.projectName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("Preset: \(appState.activePresetName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 190, alignment: .leading)
        }
    }

    private func openVideoPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .quickTimeMovie, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Video"

        if panel.runModal() == .OK, let url = panel.url {
            commandProcessor.process(.loadVideo(url: url))
        }
    }

    private func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.glitchLabProject]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Load GlitchLab Project"

        if panel.runModal() == .OK, let url = panel.url {
            commandProcessor.process(.loadProject(url: url))
        }
    }

    private func saveProjectPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.glitchLabProject]
        panel.title = "Save GlitchLab Project"
        panel.nameFieldStringValue = "\(appState.projectName).glitchlab"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            commandProcessor.process(.saveProject(url: url))
        }
    }

    private var gridToolbarTitle: String {
        if let preset = appState.gridPreset {
            return "Grid \(preset.rawValue)"
        }
        return "Grid \(appState.gridConfiguration.label)"
    }

    private var zoneToolbarTitle: String {
        switch appState.activeZonePreset {
        case .custom:
            return "Zone Custom"
        case .all:
            return "Zone All"
        default:
            return "Zone Preset"
        }
    }
}

private extension UTType {
    static var glitchLabProject: UTType {
        UTType(filenameExtension: "glitchlab") ?? .json
    }
}

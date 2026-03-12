import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    @State private var isFileImporterPresented = false
    @State private var isZonePresetBrowserPresented = false
    private let titlebarCompensation: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Divider()
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
        .padding(.top, titlebarCompensation)
        .ignoresSafeArea(.container, edges: .top)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                commandProcessor.process(.loadVideo(url: url))
            case .failure(let error):
                appState.appendLog("[ERR] file_import_error error=\(error.localizedDescription)")
            }
        }
    }

    private var topToolbar: some View {
        HStack(spacing: 12) {
            Button("Open Video") {
                isFileImporterPresented = true
            }

            Button("Load Project") {
                openProjectPanel()
            }

            Button("Save Project") {
                saveProjectPanel()
            }

            Picker(
                "Grid Preset",
                selection: Binding(
                    get: { appState.gridPreset?.rawValue ?? "Custom" },
                    set: { selected in
                        guard let preset = GridPreset(rawValue: selected) else { return }
                        commandProcessor.process(.setGrid(rows: preset.rows, cols: preset.cols))
                    }
                )
            ) {
                ForEach(GridPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset.rawValue)
                }
                Text("Custom").tag("Custom")
            }
            .pickerStyle(.menu)

            Stepper(
                "Rows \(appState.gridConfiguration.rows)",
                value: Binding(
                    get: { appState.gridConfiguration.rows },
                    set: { newRows in
                        commandProcessor.process(
                            .setGrid(rows: newRows, cols: appState.gridConfiguration.cols)
                        )
                    }
                ),
                in: 1...16
            )
            .frame(width: 110)

            Stepper(
                "Cols \(appState.gridConfiguration.cols)",
                value: Binding(
                    get: { appState.gridConfiguration.cols },
                    set: { newCols in
                        commandProcessor.process(
                            .setGrid(rows: appState.gridConfiguration.rows, cols: newCols)
                        )
                    }
                ),
                in: 1...16
            )
            .frame(width: 110)

            Button {
                isZonePresetBrowserPresented.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text("Zone Preset")
                    Text(appState.activeZonePreset.rawValue)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 130, alignment: .leading)
            }
            .popover(
                isPresented: $isZonePresetBrowserPresented,
                attachmentAnchor: .point(.bottom),
                arrowEdge: .bottom
            ) {
                ZonePresetBrowserView(activePreset: appState.activeZonePreset) { preset in
                    commandProcessor.process(.applyZonePreset(preset: preset))
                    isZonePresetBrowserPresented = false
                }
            }

            Button("Clear Zones") {
                commandProcessor.process(.clearZones)
            }

            Button("Select All") {
                commandProcessor.process(.selectAllZones)
            }

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
            .pickerStyle(.menu)

            Button("Queue Render") {
                commandProcessor.process(.render(outputURL: nil))
            }
            .disabled(appState.videoURL == nil)

            if appState.renderState.isRunning {
                Button("Cancel Render") {
                    commandProcessor.process(.cancelRender)
                }
            }

            if appState.queuedRenderCount > 0 {
                Button("Clear Queue") {
                    commandProcessor.process(.clearRenderQueue)
                }
            }

            HStack(spacing: 6) {
                if appState.renderState.isRunning {
                    ProgressView(value: appState.renderState.progress)
                        .frame(width: 90)
                }
                Text(appState.renderState.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 160, alignment: .leading)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(appState.projectName)
                    .font(.headline)
                Text("Preset: \(appState.activePresetName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 170, alignment: .trailing)
        }
        .padding(12)
        .background(.ultraThinMaterial)
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
}

private extension UTType {
    static var glitchLabProject: UTType {
        UTType(filenameExtension: "glitchlab") ?? .json
    }
}

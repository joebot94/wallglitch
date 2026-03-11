import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    @State private var isFileImporterPresented = false

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
            LogPanel()
                .frame(height: 190)
        }
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

            Picker(
                "Zone Preset",
                selection: Binding(
                    get: { appState.activeZonePreset },
                    set: { preset in
                        commandProcessor.process(.applyZonePreset(preset: preset))
                    }
                )
            ) {
                ForEach(ZoneSelectionPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Button("Clear Zones") {
                commandProcessor.process(.clearZones)
            }

            Button("Select All") {
                commandProcessor.process(.selectAllZones)
            }

            Button("Render (Placeholder)") {
                commandProcessor.process(.render(outputURL: nil))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(appState.projectName)
                    .font(.headline)
                Text("Preset: \(appState.activePresetName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }
}

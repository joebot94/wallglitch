import Foundation

@MainActor
final class CommandProcessor: ObservableObject {
    private let appState: AppState
    private let engine: GlitchEngine
    private let videoLoader: VideoLoader
    private let presetStore: PresetStore

    init(
        appState: AppState,
        engine: GlitchEngine = GlitchEngine(),
        videoLoader: VideoLoader = VideoLoader(),
        presetStore: PresetStore = PresetStore()
    ) {
        self.appState = appState
        self.engine = engine
        self.videoLoader = videoLoader
        self.presetStore = presetStore
    }

    func process(_ command: AppCommand) {
        appState.appendLog(command.logLine)

        switch command {
        case .loadVideo(let url):
            handleLoadVideo(url: url)
        case .setGrid(let rows, let cols):
            appState.gridConfiguration = GridConfiguration(rows: rows, cols: cols).clamped
            var selection = appState.zoneSelection
            selection.clamp(maxZoneID: appState.gridConfiguration.zoneCount)
            appState.zoneSelection = selection
        case .toggleZone(let id):
            mutateZoneSelection { $0.toggle(id) }
        case .enableZone(let id):
            mutateZoneSelection { $0.enable(id) }
        case .disableZone(let id):
            mutateZoneSelection { $0.disable(id) }
        case .clearZones:
            mutateZoneSelection { $0.clear() }
        case .selectAllZones:
            mutateZoneSelection { $0.selectAll(totalZones: appState.gridConfiguration.zoneCount) }
        case .setEffectEnabled(let effect, let enabled):
            updateEffect(effect) { $0.isEnabled = enabled }
        case .setEffectParameter(let effect, let parameterID, let value):
            updateEffect(effect) { current in
                guard let index = current.parameters.firstIndex(where: { $0.id == parameterID }) else { return }
                let minimum = current.parameters[index].minimum
                let maximum = current.parameters[index].maximum
                current.parameters[index].value = min(max(value, minimum), maximum)
            }
        case .setEffectTargetSelectedOnly(let effect, let selectedOnly):
            updateEffect(effect) { $0.selectedZonesOnly = selectedOnly }
        case .applyPreset(let name):
            guard let preset = presetStore.preset(named: name) else {
                appState.appendLog("[WARN] preset_not_found name=\(name)")
                return
            }
            engine.applyPreset(preset, to: appState)
        case .render(let outputURL):
            let session = engine.prepareRenderSession(
                sourceURL: appState.videoURL,
                selectedZoneIDs: appState.zoneSelection.sortedIDs,
                outputURL: outputURL
            )
            appState.appendLog(
                "[SYS] render_placeholder session=\(session.shortID) source=\(session.sourceFileName) selected_zones=\(session.selectedZoneIDs.count)"
            )
        }
    }

    private func handleLoadVideo(url: URL) {
        appState.activePresetName = "Manual"
        appState.videoURL = url
        appState.videoInfo = .loading(url: url)
        let loader = videoLoader

        Task { [weak self] in
            guard let self else { return }
            let info = await loader.loadInfo(for: url)
            await MainActor.run {
                guard self.appState.videoURL == url else { return }
                self.appState.videoInfo = info
                self.appState.appendLog(
                    "[SYS] video_info name=\(info.fileName) resolution=\(info.resolutionText) duration=\(info.durationText)"
                )
            }
        }
    }

    private func mutateZoneSelection(_ mutate: (inout ZoneSelectionModel) -> Void) {
        var selection = appState.zoneSelection
        mutate(&selection)
        selection.clamp(maxZoneID: appState.gridConfiguration.zoneCount)
        appState.zoneSelection = selection
    }

    private func updateEffect(_ effect: EffectType, mutate: (inout EffectState) -> Void) {
        guard let index = appState.effects.firstIndex(where: { $0.type == effect }) else { return }
        var updated = appState.effects
        mutate(&updated[index])
        appState.effects = updated
    }
}

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
            appState.activeZonePreset = .custom
        case .toggleZone(let id):
            mutateZoneSelection { $0.toggle(id) }
            appState.activeZonePreset = .custom
        case .enableZone(let id):
            mutateZoneSelection { $0.enable(id) }
            appState.activeZonePreset = .custom
        case .disableZone(let id):
            mutateZoneSelection { $0.disable(id) }
            appState.activeZonePreset = .custom
        case .clearZones:
            mutateZoneSelection { $0.clear() }
            appState.activeZonePreset = .custom
        case .selectAllZones:
            mutateZoneSelection { $0.selectAll(totalZones: appState.gridConfiguration.zoneCount) }
            appState.activeZonePreset = .all
        case .applyZonePreset(let preset):
            handleZonePreset(preset)
        case .seek(let seconds):
            setTimelineCurrentTime(seconds)
        case .stepFrame(let delta):
            let step = Double(delta) * appState.timeline.frameDuration
            setTimelineCurrentTime(appState.timeline.currentTimeSeconds + step)
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
        appState.timeline = TimelineState()
        let loader = videoLoader

        Task { [weak self] in
            guard let self else { return }
            let info = await loader.loadInfo(for: url)
            await MainActor.run {
                guard self.appState.videoURL == url else { return }
                self.appState.videoInfo = info
                var timeline = self.appState.timeline
                timeline.currentTimeSeconds = 0
                timeline.durationSeconds = max(info.durationSeconds ?? 0, 0)
                timeline.nominalFPS = max(info.nominalFrameRate ?? 30, 1)
                self.appState.timeline = timeline
                self.appState.appendLog(
                    "[SYS] video_info name=\(info.fileName) resolution=\(info.resolutionText) duration=\(info.durationText)"
                )
                self.appState.appendLog(
                    String(format: "[SYS] timeline_ready duration=%.3f fps=%.2f", timeline.durationSeconds, timeline.nominalFPS)
                )
            }
        }
    }

    private func handleZonePreset(_ preset: ZoneSelectionPreset) {
        guard let ids = ZonePresetResolver.zoneIDs(for: preset, grid: appState.gridConfiguration) else {
            appState.activeZonePreset = .custom
            return
        }
        var selection = ZoneSelectionModel()
        selection.set(ids: ids, maxZoneID: appState.gridConfiguration.zoneCount)
        appState.zoneSelection = selection
        appState.activeZonePreset = preset
        appState.appendLog("[SYS] zone_preset_applied name=\(preset.commandName) selected_zones=\(selection.selectedZoneIDs.count)")
    }

    private func mutateZoneSelection(_ mutate: (inout ZoneSelectionModel) -> Void) {
        var selection = appState.zoneSelection
        mutate(&selection)
        selection.clamp(maxZoneID: appState.gridConfiguration.zoneCount)
        appState.zoneSelection = selection
    }

    private func setTimelineCurrentTime(_ seconds: Double) {
        var timeline = appState.timeline
        let duration = max(timeline.durationSeconds, 0)
        let clamped = min(max(seconds, 0), duration)
        timeline.currentTimeSeconds = clamped
        appState.timeline = timeline
    }

    private func updateEffect(_ effect: EffectType, mutate: (inout EffectState) -> Void) {
        guard let index = appState.effects.firstIndex(where: { $0.type == effect }) else { return }
        var updated = appState.effects
        mutate(&updated[index])
        appState.effects = updated
    }
}

import Foundation

@MainActor
final class CommandProcessor: ObservableObject {
    private let appState: AppState
    private let engine: GlitchEngine
    private let videoLoader: VideoLoader
    private let presetStore: PresetStore
    private let offlineRenderer: OfflineVideoRenderer
    private var renderTask: Task<Void, Never>?

    init(
        appState: AppState,
        engine: GlitchEngine = GlitchEngine(),
        videoLoader: VideoLoader = VideoLoader(),
        presetStore: PresetStore = PresetStore(),
        offlineRenderer: OfflineVideoRenderer = OfflineVideoRenderer()
    ) {
        self.appState = appState
        self.engine = engine
        self.videoLoader = videoLoader
        self.presetStore = presetStore
        self.offlineRenderer = offlineRenderer
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
            appState.activeEffectPackName = "Custom"
        case .setEffectParameter(let effect, let parameterID, let value):
            updateEffect(effect) { current in
                guard let index = current.parameters.firstIndex(where: { $0.id == parameterID }) else { return }
                let minimum = current.parameters[index].minimum
                let maximum = current.parameters[index].maximum
                current.parameters[index].value = min(max(value, minimum), maximum)
            }
            appState.activeEffectPackName = "Custom"
        case .setEffectTargetSelectedOnly(let effect, let selectedOnly):
            updateEffect(effect) { $0.selectedZonesOnly = selectedOnly }
            appState.activeEffectPackName = "Custom"
        case .applyEffectPack(let name):
            handleEffectPack(name: name)
        case .applyPreset(let name):
            guard let preset = presetStore.preset(named: name) else {
                appState.appendLog("[WARN] preset_not_found name=\(name)")
                return
            }
            engine.applyPreset(preset, to: appState)
        case .render(let outputURL):
            startRender(outputURL: outputURL)
        case .cancelRender:
            cancelRender()
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

    private func handleEffectPack(name: String) {
        guard let pack = presetStore.effectPack(named: name) else {
            appState.appendLog("[WARN] effect_pack_not_found name=\(name)")
            return
        }

        var updatedEffects = appState.effects
        for index in updatedEffects.indices {
            updatedEffects[index].isEnabled = false
        }

        for setting in pack.effectSettings {
            guard let index = updatedEffects.firstIndex(where: { $0.type == setting.effect }) else {
                continue
            }
            updatedEffects[index].isEnabled = setting.enabled
            updatedEffects[index].selectedZonesOnly = setting.selectedZonesOnly
            for (parameterID, value) in setting.parameterValues {
                guard let parameterIndex = updatedEffects[index].parameters.firstIndex(where: { $0.id == parameterID }) else {
                    continue
                }
                let minimum = updatedEffects[index].parameters[parameterIndex].minimum
                let maximum = updatedEffects[index].parameters[parameterIndex].maximum
                updatedEffects[index].parameters[parameterIndex].value = min(max(value, minimum), maximum)
            }
        }

        appState.effects = updatedEffects
        appState.activeEffectPackName = pack.name
        appState.appendLog("[SYS] effect_pack_applied name=\(pack.name)")
    }

    private func startRender(outputURL: URL?) {
        guard renderTask == nil else {
            appState.appendLog("[WARN] render_already_running")
            return
        }
        guard let sourceURL = appState.videoURL else {
            appState.appendLog("[WARN] render_no_source_video")
            appState.renderState.phase = .failed(message: "No source video loaded.")
            return
        }

        let request = RenderRequest(
            sourceURL: sourceURL,
            outputURL: outputURL,
            effects: appState.effects,
            grid: appState.gridConfiguration,
            selectedZoneIDs: appState.zoneSelection.selectedZoneIDs
        )

        appState.renderState.phase = .preparing
        appState.appendLog(
            "[SYS] render_started source=\(sourceURL.lastPathComponent) selected_zones=\(request.selectedZoneIDs.count)"
        )

        let renderer = offlineRenderer
        renderTask = Task { [weak self] in
            guard let self else { return }

            do {
                let output = try await renderer.render(request: request) { progress in
                    await MainActor.run {
                        self.appState.renderState.phase = .running(progress: progress)
                    }
                }

                await MainActor.run {
                    let session = self.engine.prepareRenderSession(
                        sourceURL: sourceURL,
                        selectedZoneIDs: request.selectedZoneIDs.sorted(),
                        outputURL: output
                    )
                    self.appState.renderState.phase = .completed(outputURL: output)
                    self.appState.appendLog(
                        "[SYS] render_completed session=\(session.shortID) output=\(output.lastPathComponent)"
                    )
                    self.renderTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.appState.renderState.phase = .cancelled
                    self.appState.appendLog("[SYS] render_cancelled")
                    self.renderTask = nil
                }
            } catch {
                await MainActor.run {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    if message.lowercased().contains("cancel") {
                        self.appState.renderState.phase = .cancelled
                        self.appState.appendLog("[SYS] render_cancelled")
                    } else {
                        self.appState.renderState.phase = .failed(message: message)
                        self.appState.appendLog("[ERR] render_failed reason=\(message)")
                    }
                    self.renderTask = nil
                }
            }
        }
    }

    private func cancelRender() {
        guard let renderTask else {
            appState.appendLog("[WARN] cancel_render_without_active_job")
            return
        }
        renderTask.cancel()
        appState.appendLog("[SYS] render_cancel_requested")
    }
}

import Foundation

@MainActor
final class CommandProcessor: ObservableObject {
    private let appState: AppState
    private let engine: GlitchEngine
    private let videoLoader: VideoLoader
    private let presetStore: PresetStore
    private let projectStore: ProjectStore
    private let offlineRenderer: OfflineVideoRenderer
    private var renderTask: Task<Void, Never>?
    private let keyframeTimeEpsilon: Double = 0.0005

    init(
        appState: AppState,
        engine: GlitchEngine = GlitchEngine(),
        videoLoader: VideoLoader = VideoLoader(),
        presetStore: PresetStore = PresetStore(),
        projectStore: ProjectStore = ProjectStore(),
        offlineRenderer: OfflineVideoRenderer = OfflineVideoRenderer()
    ) {
        self.appState = appState
        self.engine = engine
        self.videoLoader = videoLoader
        self.presetStore = presetStore
        self.projectStore = projectStore
        self.offlineRenderer = offlineRenderer
    }

    func process(_ command: AppCommand) {
        appState.appendLog(command.logLine)

        switch command {
        case .loadVideo(let url):
            handleLoadVideo(url: url)
        case .saveProject(let url):
            handleSaveProject(url: url)
        case .loadProject(let url):
            handleLoadProject(url: url)
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
        case .setExportProfile(let profile):
            appState.exportProfile = profile
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
        case .setAutomationEnabled(let enabled):
            appState.automationEnabled = enabled
        case .toggleAutomationKeyframe(let effect, let parameterID, let timeSeconds, let value):
            toggleAutomationKeyframe(
                effect: effect,
                parameterID: parameterID,
                timeSeconds: timeSeconds,
                value: value
            )
        case .setAutomationLaneEnabled(let effect, let parameterID, let enabled):
            setAutomationLaneEnabled(effect: effect, parameterID: parameterID, enabled: enabled)
        case .setAutomationInterpolation(let effect, let parameterID, let mode):
            setAutomationInterpolation(effect: effect, parameterID: parameterID, mode: mode)
        case .clearAutomationLane(let effect, let parameterID):
            clearAutomationLane(effect: effect, parameterID: parameterID)
        case .clearAllAutomation:
            appState.automationLanes.removeAll()
        case .setCompareMode(let mode):
            appState.compareMode = mode
        case .setSoloEffect(let effect):
            appState.soloEffect = effect
        case .applyEffectPack(let name):
            handleEffectPack(name: name)
        case .applyPreset(let name):
            guard let preset = presetStore.preset(named: name) else {
                appState.appendLog("[WARN] preset_not_found name=\(name)")
                return
            }
            engine.applyPreset(preset, to: appState)
        case .render(let outputURL):
            enqueueRender(outputURL: outputURL)
        case .cancelRender:
            cancelRender()
        case .clearRenderQueue:
            appState.renderQueue.removeAll()
            appState.appendLog("[SYS] render_queue_cleared")
        case .removeRenderQueueItem(let id):
            appState.renderQueue.removeAll { $0.id == id }
        }
    }

    private func handleLoadVideo(url: URL) {
        appState.activePresetName = "Manual"
        appState.projectURL = nil
        loadVideoInfo(for: url)
    }

    private func handleSaveProject(url: URL) {
        let file = GlitchLabProjectFile(
            projectName: appState.projectName,
            activePresetName: appState.activePresetName,
            activeEffectPackName: appState.activeEffectPackName,
            exportProfile: appState.exportProfile,
            compareMode: appState.compareMode,
            soloEffect: appState.soloEffect,
            automationEnabled: appState.automationEnabled,
            automationLanes: appState.automationLanes,
            videoPath: appState.videoURL?.path,
            gridConfiguration: appState.gridConfiguration,
            selectedZoneIDs: appState.zoneSelection.sortedIDs,
            activeZonePreset: appState.activeZonePreset,
            effects: appState.effects
        )

        do {
            try projectStore.save(file, to: url)
            appState.projectURL = url
            appState.appendLog("[SYS] project_saved file=\(url.lastPathComponent)")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            appState.appendLog("[ERR] project_save_failed reason=\(message)")
        }
    }

    private func handleLoadProject(url: URL) {
        do {
            let file = try projectStore.load(from: url)
            applyProjectFile(file, sourceURL: url)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            appState.appendLog("[ERR] project_load_failed reason=\(message)")
        }
    }

    private func applyProjectFile(_ file: GlitchLabProjectFile, sourceURL: URL) {
        appState.projectURL = sourceURL
        appState.projectName = file.projectName
        appState.activePresetName = file.activePresetName
        appState.activeEffectPackName = file.activeEffectPackName
        appState.exportProfile = file.exportProfile
        appState.compareMode = file.compareMode
        appState.soloEffect = file.soloEffect
        appState.automationEnabled = file.automationEnabled
        appState.gridConfiguration = file.gridConfiguration.clamped
        appState.activeZonePreset = file.activeZonePreset

        var selection = ZoneSelectionModel()
        selection.set(ids: Set(file.selectedZoneIDs), maxZoneID: appState.gridConfiguration.zoneCount)
        appState.zoneSelection = selection

        appState.effects = mergeLoadedEffects(file.effects)
        appState.automationLanes = normalizeAutomationLanes(file.automationLanes)

        appState.renderQueue.removeAll()
        appState.activeRenderJob = nil
        appState.renderState.phase = .idle

        if let videoPath = file.videoPath {
            let candidateURL = URL(fileURLWithPath: videoPath)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                loadVideoInfo(for: candidateURL)
            } else {
                appState.videoURL = nil
                appState.videoInfo = nil
                appState.timeline = TimelineState()
                appState.appendLog("[WARN] project_video_missing path=\(videoPath)")
            }
        } else {
            appState.videoURL = nil
            appState.videoInfo = nil
            appState.timeline = TimelineState()
        }

        appState.appendLog("[SYS] project_loaded file=\(sourceURL.lastPathComponent)")
    }

    private func mergeLoadedEffects(_ loadedEffects: [EffectState]) -> [EffectState] {
        var merged = DefaultEffectCatalog.makeDefaultEffects()

        for loaded in loadedEffects {
            guard let effectIndex = merged.firstIndex(where: { $0.type == loaded.type }) else { continue }
            merged[effectIndex].isEnabled = loaded.isEnabled
            merged[effectIndex].selectedZonesOnly = loaded.selectedZonesOnly

            for loadedParameter in loaded.parameters {
                guard let parameterIndex = merged[effectIndex].parameters.firstIndex(where: { $0.id == loadedParameter.id }) else {
                    continue
                }
                let minimum = merged[effectIndex].parameters[parameterIndex].minimum
                let maximum = merged[effectIndex].parameters[parameterIndex].maximum
                merged[effectIndex].parameters[parameterIndex].value = min(max(loadedParameter.value, minimum), maximum)
            }
        }

        return merged
    }

    private func loadVideoInfo(for url: URL) {
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

    private func enqueueRender(outputURL: URL?) {
        guard let sourceURL = appState.videoURL else {
            appState.appendLog("[WARN] render_no_source_video")
            appState.renderState.phase = .failed(message: "No source video loaded.")
            return
        }

        let item = RenderQueueItem(
            id: UUID(),
            enqueuedAt: Date(),
            sourceURL: sourceURL,
            outputURL: outputURL,
            exportProfile: appState.exportProfile,
            effects: appState.effects,
            grid: appState.gridConfiguration,
            selectedZoneIDs: appState.zoneSelection.selectedZoneIDs,
            compareMode: appState.compareMode,
            soloEffect: appState.soloEffect,
            automationEnabled: appState.automationEnabled,
            automationLanes: appState.automationLanes
        )

        appState.renderQueue.append(item)
        appState.appendLog(
            "[SYS] render_queued id=\(item.id.uuidString.prefix(8)) source=\(sourceURL.lastPathComponent) compare=\(item.compareMode.commandName) queue=\(appState.renderQueue.count)"
        )
        startNextQueuedRenderIfNeeded()
    }

    private func startNextQueuedRenderIfNeeded() {
        guard renderTask == nil else { return }
        guard !appState.renderQueue.isEmpty else { return }

        let next = appState.renderQueue.removeFirst()
        appState.activeRenderJob = next
        startRender(job: next)
    }

    private func startRender(job: RenderQueueItem) {
        let request = RenderRequest(
            sourceURL: job.sourceURL,
            outputURL: job.outputURL,
            exportProfile: job.exportProfile,
            effects: effectiveEffects(for: job),
            grid: job.grid,
            selectedZoneIDs: job.selectedZoneIDs,
            automationEnabled: job.automationEnabled,
            automationLanes: job.automationLanes
        )

        appState.renderState.phase = .preparing
        appState.appendLog(
            "[SYS] render_started source=\(job.sourceName) profile=\(request.exportProfile.commandName) compare=\(job.compareMode.commandName) selected_zones=\(request.selectedZoneIDs.count)"
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
                        sourceURL: job.sourceURL,
                        selectedZoneIDs: request.selectedZoneIDs.sorted(),
                        outputURL: output
                    )
                    self.appState.renderState.phase = .completed(outputURL: output)
                    self.appState.appendLog(
                        "[SYS] render_completed session=\(session.shortID) output=\(output.lastPathComponent)"
                    )
                    self.appState.activeRenderJob = nil
                    self.renderTask = nil
                    self.startNextQueuedRenderIfNeeded()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.appState.renderState.phase = .cancelled
                    self.appState.appendLog("[SYS] render_cancelled")
                    self.appState.activeRenderJob = nil
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
                    self.appState.activeRenderJob = nil
                    self.renderTask = nil
                    self.startNextQueuedRenderIfNeeded()
                }
            }
        }
    }

    private func effectiveEffects(for job: RenderQueueItem) -> [EffectState] {
        if job.compareMode == .original {
            return job.effects.map { effect in
                var copy = effect
                copy.isEnabled = false
                return copy
            }
        }

        guard let soloEffect = job.soloEffect else {
            return job.effects
        }

        return job.effects.map { effect in
            var copy = effect
            if copy.type != soloEffect {
                copy.isEnabled = false
            }
            return copy
        }
    }

    private func cancelRender() {
        guard let renderTask else {
            appState.appendLog("[WARN] cancel_render_without_active_job")
            return
        }

        renderTask.cancel()
        if !appState.renderQueue.isEmpty {
            appState.renderQueue.removeAll()
            appState.appendLog("[SYS] render_queue_cleared reason=cancel_render")
        }
        appState.appendLog("[SYS] render_cancel_requested")
    }

    private func toggleAutomationKeyframe(
        effect: EffectType,
        parameterID: String,
        timeSeconds: Double,
        value: Double
    ) {
        guard let parameter = parameterDefinition(effect: effect, parameterID: parameterID) else {
            appState.appendLog("[WARN] keyframe_parameter_not_found effect=\(effect.commandName) parameter=\(parameterID)")
            return
        }

        let maxDuration = max(appState.timeline.durationSeconds, 0)
        let clampedTime = min(max(timeSeconds, 0), maxDuration > 0 ? maxDuration : timeSeconds)
        let clampedValue = min(max(value, parameter.minimum), parameter.maximum)
        let epsilon = max(keyframeTimeEpsilon, appState.timeline.frameDuration * 0.45)

        var lanes = appState.automationLanes
        let laneID = laneIdentifier(effect: effect, parameterID: parameterID)
        let laneIndex: Int
        if let existingIndex = lanes.firstIndex(where: { $0.id == laneID }) {
            laneIndex = existingIndex
        } else {
            lanes.append(
                ParameterAutomationLane(
                    effect: effect,
                    parameterID: parameterID,
                    isEnabled: true,
                    interpolation: .linear,
                    keyframes: []
                )
            )
            laneIndex = lanes.count - 1
        }

        if let existingKeyframeIndex = lanes[laneIndex].keyframes.firstIndex(where: {
            abs($0.timeSeconds - clampedTime) <= epsilon
        }) {
            lanes[laneIndex].keyframes.remove(at: existingKeyframeIndex)
            if lanes[laneIndex].keyframes.isEmpty {
                lanes.remove(at: laneIndex)
            }
        } else {
            lanes[laneIndex].keyframes.append(
                ParameterKeyframe(timeSeconds: clampedTime, value: clampedValue)
            )
            lanes[laneIndex].keyframes.sort { $0.timeSeconds < $1.timeSeconds }
        }

        appState.automationLanes = lanes
    }

    private func setAutomationLaneEnabled(effect: EffectType, parameterID: String, enabled: Bool) {
        guard let parameter = parameterDefinition(effect: effect, parameterID: parameterID) else {
            appState.appendLog("[WARN] lane_parameter_not_found effect=\(effect.commandName) parameter=\(parameterID)")
            return
        }

        var lanes = appState.automationLanes
        let laneID = laneIdentifier(effect: effect, parameterID: parameterID)
        if let index = lanes.firstIndex(where: { $0.id == laneID }) {
            lanes[index].isEnabled = enabled
        } else {
            let value = currentEffectParameterValue(effect: effect, parameterID: parameterID) ?? parameter.value
            lanes.append(
                ParameterAutomationLane(
                    effect: effect,
                    parameterID: parameterID,
                    isEnabled: enabled,
                    interpolation: .linear,
                    keyframes: [ParameterKeyframe(timeSeconds: appState.timeline.currentTimeSeconds, value: value)]
                )
            )
        }
        appState.automationLanes = lanes
    }

    private func setAutomationInterpolation(effect: EffectType, parameterID: String, mode: AutomationInterpolation) {
        let laneID = laneIdentifier(effect: effect, parameterID: parameterID)
        guard let laneIndex = appState.automationLanes.firstIndex(where: { $0.id == laneID }) else {
            return
        }
        var lanes = appState.automationLanes
        lanes[laneIndex].interpolation = mode
        appState.automationLanes = lanes
    }

    private func clearAutomationLane(effect: EffectType, parameterID: String) {
        let laneID = laneIdentifier(effect: effect, parameterID: parameterID)
        appState.automationLanes.removeAll { $0.id == laneID }
    }

    private func parameterDefinition(effect: EffectType, parameterID: String) -> EffectParameter? {
        appState
            .effectState(for: effect)?
            .parameters
            .first(where: { $0.id == parameterID })
    }

    private func currentEffectParameterValue(effect: EffectType, parameterID: String) -> Double? {
        appState.effectState(for: effect)?
            .parameters
            .first(where: { $0.id == parameterID })?
            .value
    }

    private func laneIdentifier(effect: EffectType, parameterID: String) -> String {
        "\(effect.rawValue)::\(parameterID)"
    }

    private func normalizeAutomationLanes(_ rawLanes: [ParameterAutomationLane]) -> [ParameterAutomationLane] {
        var normalized: [ParameterAutomationLane] = []
        let duration = max(appState.timeline.durationSeconds, 0)

        for lane in rawLanes {
            guard let parameter = parameterDefinition(effect: lane.effect, parameterID: lane.parameterID) else {
                continue
            }

            var lastTime: Double?
            var cleanKeyframes: [ParameterKeyframe] = []
            let sorted = lane.keyframes.sorted { $0.timeSeconds < $1.timeSeconds }

            for keyframe in sorted {
                let clampedTime = min(max(keyframe.timeSeconds, 0), duration > 0 ? duration : keyframe.timeSeconds)
                if let lastTime, abs(lastTime - clampedTime) <= keyframeTimeEpsilon {
                    cleanKeyframes[cleanKeyframes.count - 1].value = min(max(keyframe.value, parameter.minimum), parameter.maximum)
                } else {
                    cleanKeyframes.append(
                        ParameterKeyframe(
                            id: keyframe.id,
                            timeSeconds: clampedTime,
                            value: min(max(keyframe.value, parameter.minimum), parameter.maximum)
                        )
                    )
                    lastTime = clampedTime
                }
            }

            guard !cleanKeyframes.isEmpty else { continue }
            normalized.append(
                ParameterAutomationLane(
                    effect: lane.effect,
                    parameterID: lane.parameterID,
                    isEnabled: lane.isEnabled,
                    interpolation: lane.interpolation,
                    keyframes: cleanKeyframes
                )
            )
        }

        return normalized
    }
}

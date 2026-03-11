import Foundation

@MainActor
final class GlitchEngine {
    private(set) var lastRenderSession: RenderSession?

    func applyPreset(_ preset: Preset, to appState: AppState) {
        appState.activePresetName = preset.name
        appState.gridConfiguration = preset.grid.clamped

        var selection = ZoneSelectionModel()
        for id in preset.selectedZoneIDs {
            selection.enable(id)
        }
        selection.clamp(maxZoneID: appState.gridConfiguration.zoneCount)
        appState.zoneSelection = selection

        var updatedEffects = appState.effects
        for setting in preset.effectSettings {
            guard let index = updatedEffects.firstIndex(where: { $0.type == setting.effect }) else { continue }
            updatedEffects[index].isEnabled = setting.enabled
            updatedEffects[index].selectedZonesOnly = setting.selectedZonesOnly
            for (parameterID, value) in setting.parameterValues {
                guard let parameterIndex = updatedEffects[index].parameters.firstIndex(where: { $0.id == parameterID }) else {
                    continue
                }
                updatedEffects[index].parameters[parameterIndex].value = value
            }
        }
        appState.effects = updatedEffects
    }

    func prepareRenderSession(
        sourceURL: URL?,
        selectedZoneIDs: [Int],
        outputURL: URL?
    ) -> RenderSession {
        let session = RenderSession(
            id: UUID(),
            createdAt: Date(),
            sourceURL: sourceURL,
            outputURL: outputURL,
            selectedZoneIDs: selectedZoneIDs
        )
        lastRenderSession = session
        return session
    }
}

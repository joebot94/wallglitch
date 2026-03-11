import SwiftUI

@main
struct GlitchLabApp: App {
    @StateObject private var appState: AppState
    @StateObject private var commandProcessor: CommandProcessor

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        _commandProcessor = StateObject(wrappedValue: CommandProcessor(appState: appState))
    }

    var body: some Scene {
        WindowGroup("GlitchLab") {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(commandProcessor)
                .frame(minWidth: 1200, minHeight: 760)
        }
    }
}

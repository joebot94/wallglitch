import SwiftUI

struct LogPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Command Log")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            List(appState.commandLog.suffix(250)) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Text(AppFormatters.logTime.string(from: entry.timestamp))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .leading)

                    Text(entry.message)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding(.vertical, 1)
            }
            .listStyle(.plain)
        }
    }
}

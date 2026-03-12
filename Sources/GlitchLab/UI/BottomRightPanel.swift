import SwiftUI

struct BottomRightPanel: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Render Queue")
                    .font(.headline)
                Spacer()
                Text("\(appState.queuedRenderCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if appState.queuedRenderCount > 0 {
                    Button("Clear") {
                        commandProcessor.process(.clearRenderQueue)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)

            if let activeRenderJob = appState.activeRenderJob {
                Text("Now: \(activeRenderJob.sourceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            } else {
                Text("Now: Idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }

            List {
                ForEach(appState.renderQueue) { item in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.sourceName)
                                .lineLimit(1)
                            Text(item.exportProfile.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            commandProcessor.process(.removeRenderQueueItem(id: item.id))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption)
                }

                if appState.renderQueue.isEmpty {
                    Text("Queue is empty")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .listStyle(.plain)
        }
    }
}

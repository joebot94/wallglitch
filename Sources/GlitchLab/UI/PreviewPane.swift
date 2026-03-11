import AppKit
import AVFoundation
import Foundation
import SwiftUI

struct PreviewPane: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var commandProcessor: CommandProcessor

    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
                .padding(.top, 10)
                .padding(.horizontal, 12)

            GeometryReader { geometry in
                let aspectRatio = appState.videoInfo?.aspectRatio ?? (16.0 / 9.0)
                let canvasSize = fittedSize(in: geometry.size, aspectRatio: aspectRatio)

                ZStack {
                    previewLayer
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .background(Color.black.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    GridOverlayView(
                        grid: appState.gridConfiguration,
                        selectedZoneIDs: appState.zoneSelection.selectedZoneIDs
                    ) { zoneID in
                        commandProcessor.process(.toggleZone(id: zoneID))
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 12)

            timelineControls
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .onAppear {
            configurePlayer(with: appState.videoURL)
        }
        .onChange(of: appState.videoURL) { newValue in
            configurePlayer(with: newValue)
        }
        .onChange(of: appState.timeline.currentTimeSeconds) { newValue in
            seekPlayer(to: newValue)
        }
    }

    @ViewBuilder
    private var previewLayer: some View {
        if let player {
            PlayerSurfaceView(player: player)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "film")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Open a video to start")
                    .foregroundStyle(.white.opacity(0.8))
                Text("Grid selection works on this placeholder too")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func configurePlayer(with url: URL?) {
        guard let url else {
            player = nil
            return
        }
        let candidate = AVPlayer(url: url)
        candidate.pause()
        candidate.actionAtItemEnd = .pause
        player = candidate
        seekPlayer(to: appState.timeline.currentTimeSeconds)
    }

    private var timelineControls: some View {
        let duration = appState.timeline.durationSeconds
        let current = appState.timeline.currentTimeSeconds
        let isEnabled = duration > 0

        return HStack(spacing: 8) {
            Button("<<") {
                commandProcessor.process(.seek(seconds: 0))
            }
            .disabled(!isEnabled)

            Button("<") {
                commandProcessor.process(.stepFrame(delta: -1))
            }
            .disabled(!isEnabled)

            Text(AppFormatters.durationString(seconds: current))
                .font(.system(.caption, design: .monospaced))
                .frame(width: 56, alignment: .leading)

            Slider(
                value: Binding(
                    get: { appState.timeline.currentTimeSeconds },
                    set: { seconds in
                        commandProcessor.process(.seek(seconds: seconds))
                    }
                ),
                in: 0...max(duration, 0.001)
            )
            .disabled(!isEnabled)

            Text(AppFormatters.durationString(seconds: duration))
                .font(.system(.caption, design: .monospaced))
                .frame(width: 56, alignment: .trailing)

            Button(">") {
                commandProcessor.process(.stepFrame(delta: 1))
            }
            .disabled(!isEnabled)

            Button(">>") {
                commandProcessor.process(.seek(seconds: duration))
            }
            .disabled(!isEnabled)

            Text(String(format: "%.2f fps", appState.timeline.nominalFPS))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
    }

    private func seekPlayer(to seconds: Double) {
        guard let player else { return }
        let target = CMTime(seconds: max(seconds, 0), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func fittedSize(in container: CGSize, aspectRatio: CGFloat) -> CGSize {
        guard container.width > 0, container.height > 0 else { return .zero }

        let maxWidth = container.width
        let maxHeight = container.height
        let widthFromHeight = maxHeight * aspectRatio

        if widthFromHeight <= maxWidth {
            return CGSize(width: widthFromHeight, height: maxHeight)
        }

        let heightFromWidth = maxWidth / aspectRatio
        return CGSize(width: maxWidth, height: heightFromWidth)
    }
}

private struct PlayerSurfaceView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerContainerNSView {
        let view = PlayerContainerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerContainerNSView, context: Context) {
        nsView.player = player
    }
}

private final class PlayerContainerNSView: NSView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

import AppKit
import AVFoundation
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
            .padding(.bottom, 12)
        }
        .onAppear {
            configurePlayer(with: appState.videoURL)
        }
        .onChange(of: appState.videoURL) { newValue in
            configurePlayer(with: newValue)
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

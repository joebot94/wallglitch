import AVFoundation
import Foundation

actor VideoLoader {
    func loadInfo(for url: URL) async -> VideoAssetInfo {
        let asset = AVURLAsset(url: url)
        var width: Int?
        var height: Int?
        var durationSeconds: Double?
        var nominalFrameRate: Double?

        if let duration = try? await asset.load(.duration) {
            durationSeconds = duration.seconds
        }

        if
            let track = try? await asset.loadTracks(withMediaType: .video).first,
            let naturalSize = try? await track.load(.naturalSize),
            let transform = try? await track.load(.preferredTransform)
        {
            let transformed = naturalSize.applying(transform)
            width = Int(abs(transformed.width).rounded())
            height = Int(abs(transformed.height).rounded())
            if let rate = try? await track.load(.nominalFrameRate) {
                nominalFrameRate = Double(rate)
            }
        }

        return VideoAssetInfo(
            url: url,
            fileName: url.lastPathComponent,
            width: width,
            height: height,
            durationSeconds: durationSeconds,
            nominalFrameRate: nominalFrameRate
        )
    }
}

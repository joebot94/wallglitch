import CoreGraphics
import Foundation

struct VideoAssetInfo: Equatable {
    let url: URL
    let fileName: String
    let width: Int?
    let height: Int?
    let durationSeconds: Double?

    var resolutionText: String {
        guard let width, let height else { return "Unknown" }
        return "\(width)x\(height)"
    }

    var durationText: String {
        guard let durationSeconds else { return "Unknown" }
        return AppFormatters.durationString(seconds: durationSeconds)
    }

    var aspectRatio: CGFloat? {
        guard let width, let height, height > 0 else { return nil }
        return CGFloat(width) / CGFloat(height)
    }

    static func loading(url: URL) -> VideoAssetInfo {
        VideoAssetInfo(
            url: url,
            fileName: url.lastPathComponent,
            width: nil,
            height: nil,
            durationSeconds: nil
        )
    }
}

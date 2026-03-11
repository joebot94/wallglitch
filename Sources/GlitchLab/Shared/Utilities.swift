import CoreMedia
import Foundation

enum AppFormatters {
    static let logTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static func durationString(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "Unknown" }
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func durationString(time: CMTime) -> String {
        durationString(seconds: time.seconds)
    }

    static func parameterString(value: Double, step: Double, unit: String?) -> String {
        let decimals = step >= 1 ? 0 : 2
        let text = String(format: "%.\(decimals)f", value)
        if let unit {
            return "\(text)\(unit)"
        }
        return text
    }
}

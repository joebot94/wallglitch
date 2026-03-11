import Foundation

struct RenderSession {
    let id: UUID
    let createdAt: Date
    let sourceURL: URL?
    let outputURL: URL?
    let selectedZoneIDs: [Int]

    var shortID: String {
        String(id.uuidString.prefix(8))
    }

    var sourceFileName: String {
        sourceURL?.lastPathComponent ?? "none"
    }
}

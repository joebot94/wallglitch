import Foundation

enum ProjectStoreError: LocalizedError {
    case failedToEncode
    case failedToDecode

    var errorDescription: String? {
        switch self {
        case .failedToEncode:
            return "Failed to encode project file."
        case .failedToDecode:
            return "Failed to decode project file."
        }
    }
}

struct ProjectStore {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func save(_ file: GlitchLabProjectFile, to url: URL) throws {
        guard let data = try? encoder.encode(file) else {
            throw ProjectStoreError.failedToEncode
        }
        try data.write(to: url, options: .atomic)
    }

    func load(from url: URL) throws -> GlitchLabProjectFile {
        let data = try Data(contentsOf: url)
        guard let file = try? decoder.decode(GlitchLabProjectFile.self, from: data) else {
            throw ProjectStoreError.failedToDecode
        }
        return file
    }
}

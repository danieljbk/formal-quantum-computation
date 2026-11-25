import Foundation

/// Reads and writes `PersistedState` as JSON in Application Support.
enum PersistenceController {
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CradleCall", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func load(from url: URL = fileURL) -> PersistedState {
        guard let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(PersistedState.self, from: data) else {
            return .sample
        }
        return state
    }

    static func save(_ state: PersistedState, to url: URL = fileURL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("CradleCall: failed to save state: \(error)")
        }
    }
}

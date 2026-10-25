import Application
import Foundation

/// `SyncMetadata` en un fichero JSON junto a los datos.
public struct JSONFileSyncMetadataStore: SyncMetadataStore {
    private struct Stored: Codable {
        var needsUpload: Bool
        var revision: String?
    }

    private let file: URL

    public init(file: URL) {
        self.file = file
    }

    /// `Application Support/GymCompanion/sync.json`.
    public static func applicationSupport() throws -> JSONFileSyncMetadataStore {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return JSONFileSyncMetadataStore(file: base.appendingPathComponent("GymCompanion/sync.json"))
    }

    public func load() async throws -> SyncMetadata {
        guard FileManager.default.fileExists(atPath: file.path) else { return SyncMetadata() }
        let stored = try JSONDecoder().decode(Stored.self, from: Data(contentsOf: file))
        return SyncMetadata(needsUpload: stored.needsUpload, revision: stored.revision)
    }

    public func save(_ metadata: SyncMetadata) async throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Stored(needsUpload: metadata.needsUpload, revision: metadata.revision)).write(to: file, options: .atomic)
    }
}

import Application
import Foundation

/// La configuración de la sincronización en un JSON junto a los datos
/// (`Application Support/GymCompanion/sync.json`). El token no va aquí: va al Llavero.
public struct JSONFileSyncSettingsStore: SyncSettingsStore {
    private struct Stored: Codable {
        var location: SyncLocation?
        var hasPendingUpload: Bool
    }

    private let file: URL

    public init(file: URL) {
        self.file = file
    }

    public static func applicationSupport() throws -> JSONFileSyncSettingsStore {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return JSONFileSyncSettingsStore(file: base.appendingPathComponent("GymCompanion/sync.json"))
    }

    public func load() async throws -> SyncSettings {
        guard FileManager.default.fileExists(atPath: file.path) else { return SyncSettings() }
        let stored = try JSONDecoder().decode(Stored.self, from: Data(contentsOf: file))
        return SyncSettings(location: stored.location, hasPendingUpload: stored.hasPendingUpload)
    }

    public func save(_ settings: SyncSettings) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(Stored(location: settings.location, hasPendingUpload: settings.hasPendingUpload)).write(to: file, options: .atomic)
    }
}

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
        JSONFileSyncSettingsStore(file: try JSONFile.applicationSupport("sync.json"))
    }

    public func load() async throws -> SyncSettings {
        guard let contents = try JSONFile.read(file) else { return SyncSettings() }
        let stored = try JSONDecoder().decode(Stored.self, from: contents)
        return SyncSettings(location: stored.location, hasPendingUpload: stored.hasPendingUpload)
    }

    public func save(_ settings: SyncSettings) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try JSONFile.write(encoder.encode(Stored(location: settings.location, hasPendingUpload: settings.hasPendingUpload)), to: file)
    }
}

import Application
import Foundation

/// La configuración de la sincronización en un JSON junto a los datos
/// (`Application Support/GymCompanion/sync.json`). El token no va aquí: va al Llavero.
public struct JSONFileSyncSettingsStore: SyncSettingsStore {
    /// El formato del fichero, propio del adaptador (como `StoredTrainingData`): así cambiar el
    /// modelo no rompe lo que ya está guardado.
    private struct Stored: Codable {
        struct Location: Codable {
            var repository: String
            var branch: String
            var path: String
        }

        var location: Location?
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
        let location = stored.location.map { SyncLocation(repository: $0.repository, branch: $0.branch, path: $0.path) }
        return SyncSettings(location: location, hasPendingUpload: stored.hasPendingUpload)
    }

    public func save(_ settings: SyncSettings) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let location = settings.location.map { Stored.Location(repository: $0.repository, branch: $0.branch, path: $0.path) }
        try JSONFile.write(encoder.encode(Stored(location: location, hasPendingUpload: settings.hasPendingUpload)), to: file)
    }
}

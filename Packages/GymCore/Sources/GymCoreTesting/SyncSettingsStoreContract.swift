import Application
import Domain
import Testing

/// Lo que cualquier `SyncSettingsStore` tiene que cumplir (ver `TrainingDataStoreContract`).
public enum SyncSettingsStoreContract: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case emptyLoadsDefaults = "sin nada guardado, sin configurar y sin pendientes"
    case savedLoads = "lo guardado se lee igual en otro arranque"
    case lastSaveWins = "lo último guardado gana"
    case clearsLocation = "se puede quitar la configuración"

    public var testDescription: String { rawValue }

    public func verify(makeStores: () throws -> () -> any SyncSettingsStore) async throws {
        let open = try makeStores()
        let configured = SyncSettings(location: SyncLocation(repository: "u/r", branch: "main", path: "datos/db.json"), hasPendingUpload: true)
        switch self {
        case .emptyLoadsDefaults:
            #expect(try await open().load() == SyncSettings())
        case .savedLoads:
            try await open().save(configured)
            #expect(try await open().load() == configured)
        case .lastSaveWins:
            let store = open()
            try await store.save(configured)
            try await store.save(SyncSettings(location: SyncLocation(repository: "otro/repo"), hasPendingUpload: false))
            #expect(try await open().load() == SyncSettings(location: SyncLocation(repository: "otro/repo"), hasPendingUpload: false))
        case .clearsLocation:
            try await open().save(configured)
            try await open().save(SyncSettings(location: nil, hasPendingUpload: true))
            #expect(try await open().load() == SyncSettings(location: nil, hasPendingUpload: true))
        }
    }
}

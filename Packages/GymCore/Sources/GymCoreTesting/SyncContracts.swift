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

/// Lo que cualquier `CredentialStore` tiene que cumplir. `makeStores` empieza sin token.
public enum CredentialStoreContract: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case emptyHasNoToken = "sin nada guardado, sin token"
    case savedReads = "el token guardado se lee en otro arranque"
    case replaces = "guardar otro token sustituye al anterior"
    case deletes = "nil borra el token"

    public var testDescription: String { rawValue }

    public func verify(makeStores: () throws -> () -> any CredentialStore) async throws {
        let open = try makeStores()
        switch self {
        case .emptyHasNoToken:
            #expect(try await open().token() == nil)
        case .savedReads:
            try await open().setToken("ghp_uno")
            #expect(try await open().token() == "ghp_uno")
        case .replaces:
            try await open().setToken("ghp_uno")
            try await open().setToken("ghp_dos")
            #expect(try await open().token() == "ghp_dos")
        case .deletes:
            try await open().setToken("ghp_uno")
            try await open().setToken(nil)
            #expect(try await open().token() == nil)
            try await open().setToken(nil)
            #expect(try await open().token() == nil)
        }
    }
}

/// Lo que cualquier `RemoteTrainingDataSource` tiene que cumplir, con las reglas del `sha` de la
/// API de contenidos de GitHub. `makeSource` da un remoto vacío (sin fichero).
public enum RemoteTrainingDataSourceContract: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case missingIs404 = "sin fichero, leer da 404"
    case createsAndReads = "subir sin versión crea el fichero y se lee igual"
    case replacesCurrent = "subir encima de la versión actual la sustituye"
    case staleIsConflict = "subir encima de una versión vieja es un conflicto"
    case missingVersionIsConflict = "subir sin versión encima de un fichero que existe es un conflicto"

    public var testDescription: String { rawValue }

    public func verify(makeSource: () throws -> (any RemoteTrainingDataSource, SyncLocation, String)) async throws {
        let (source, location, token) = try makeSource()
        let sample = Self.sample
        switch self {
        case .missingIs404:
            await #expect(throws: RemoteError.status(404)) { try await source.fetch(location, token: token) }
        case .createsAndReads:
            let version = try await source.push(sample, to: location, token: token, replacing: nil, message: "crear")
            #expect(try await source.fetch(location, token: token) == RemoteSnapshot(data: sample, version: version))
        case .replacesCurrent:
            let first = try await source.push(TrainingData(), to: location, token: token, replacing: nil, message: "crear")
            let second = try await source.push(sample, to: location, token: token, replacing: first, message: "cambiar")
            #expect(second != first)
            #expect(try await source.fetch(location, token: token) == RemoteSnapshot(data: sample, version: second))
        case .staleIsConflict:
            let first = try await source.push(TrainingData(), to: location, token: token, replacing: nil, message: "crear")
            _ = try await source.push(sample, to: location, token: token, replacing: first, message: "cambiar")
            await #expect(throws: RemoteError.conflict) {
                try await source.push(TrainingData(), to: location, token: token, replacing: first, message: "viejo")
            }
            #expect(try await source.fetch(location, token: token).data == sample)
        case .missingVersionIsConflict:
            _ = try await source.push(sample, to: location, token: token, replacing: nil, message: "crear")
            await #expect(throws: RemoteError.conflict) {
                try await source.push(TrainingData(), to: location, token: token, replacing: nil, message: "sin sha")
            }
        }
    }

    /// `TrainingDataStoreContract.sample` con lo que el `db.json` de la PWA puede guardar: las
    /// rutinas DIA1–DIA3 con su nombre y en su orden, y las demás detrás con el id por nombre.
    public static let sample: TrainingData = {
        var sample = TrainingDataStoreContract.sample
        sample.routines = [
            Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl"]),
            Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["sin_grupo"]),
            Routine(id: "EXTRA", name: "EXTRA", exerciseIDs: []),
        ]
        return sample
    }()
}

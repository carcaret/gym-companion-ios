import Domain

/// Dónde está el `db.json` que se sincroniza: un fichero de una rama de un repositorio de GitHub.
public struct SyncLocation: Hashable, Sendable, Codable {
    /// "usuario/repositorio".
    public var repository: String
    public var branch: String
    public var path: String

    /// Rama y ruta por defecto, las de la PWA.
    public init(repository: String, branch: String = "master", path: String = "db.json") {
        self.repository = repository
        self.branch = branch
        self.path = path
    }
}

/// Lo que se recuerda de la sincronización entre arranques (el token no: va al Llavero).
public struct SyncSettings: Hashable, Sendable {
    /// `nil` = sin configurar.
    public var location: SyncLocation?
    /// Hay cambios guardados en local que aún no se han subido (el `needs_upload` de la PWA).
    public var hasPendingUpload: Bool

    public init(location: SyncLocation? = nil, hasPendingUpload: Bool = false) {
        self.location = location
        self.hasPendingUpload = hasPendingUpload
    }
}

/// Puerto: dónde se guarda la configuración de la sincronización.
public protocol SyncSettingsStore: Sendable {
    /// La guardada, o la vacía si nunca se guardó. Lanza si hay algo que no se puede leer.
    func load() async throws -> SyncSettings
    func save(_ settings: SyncSettings) async throws
}

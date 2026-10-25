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

/// Puerto: dónde se guarda el token de GitHub (en el iPhone, el Llavero; nunca en un fichero).
public protocol CredentialStore: Sendable {
    func token() async throws -> String?
    /// `nil` lo borra.
    func setToken(_ token: String?) async throws
}

/// La versión del fichero remoto que se conoce (en GitHub, el `sha`). Subir encima de otra
/// versión que no es la actual es un conflicto.
public struct RemoteVersion: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

/// Los datos remotos y su versión.
public struct RemoteSnapshot: Hashable, Sendable {
    public var data: TrainingData
    public var version: RemoteVersion

    public init(data: TrainingData, version: RemoteVersion) {
        self.data = data
        self.version = version
    }
}

/// Por qué falló una operación con el remoto.
public enum RemoteError: Error, Hashable, Sendable {
    /// Sin red, o el servidor no responde.
    case unreachable
    /// Respuesta con un código de error (401 token malo, 404 no existe...).
    case status(Int)
    /// La versión remota no es la que se creía (alguien la cambió): el 409/422 de GitHub.
    case conflict
    /// Lo que hay en el remoto no se puede leer como datos de la app.
    case invalidContent
}

/// Puerto: el remoto con el que se sincroniza (el `db.json` de GitHub que usa la PWA).
public protocol RemoteTrainingDataSource: Sendable {
    func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> RemoteSnapshot

    /// Sube los datos encima de `version` (`nil` = el fichero aún no existe) y devuelve la nueva.
    func push(_ data: TrainingData, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
              message: String) async throws(RemoteError) -> RemoteVersion
}

/// Puerto: pedir al sistema que deje terminar un trabajo aunque la app pase a segundo plano (el
/// `keepalive` del `fetch` de la PWA; en iOS, una tarea en segundo plano).
public protocol BackgroundActivity: Sendable {
    func run(_ work: @escaping @Sendable () async -> Void) async
}

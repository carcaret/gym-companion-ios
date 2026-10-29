import Domain

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
    /// `day`: cuándo se sube (en GitHub, va en el mensaje del commit).
    func push(_ data: TrainingData, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
              on day: LocalDate) async throws(RemoteError) -> RemoteVersion
}

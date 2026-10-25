import Domain

/// Lo que hay en el remoto (el `db.json` de GitHub) y su revisión.
public struct RemoteSnapshot: Hashable, Sendable {
    public let data: TrainingData
    /// Identifica la versión del remoto (el `sha` del fichero en GitHub): subir encima de otra
    /// distinta es un conflicto.
    public let revision: String

    public init(data: TrainingData, revision: String) {
        self.data = data
        self.revision = revision
    }
}

/// Por qué falló una operación con el remoto.
public enum RemoteError: Error, Hashable, Sendable {
    /// Sin token, o el token no vale (401/403).
    case unauthorized
    /// El repo, la rama o el fichero no existen (404).
    case notFound
    /// El remoto cambió desde la revisión que se tenía (409/422).
    case conflict
    /// Sin red o el servidor no responde.
    case unavailable
    /// El fichero no es un `db.json` válido.
    case invalidContent
    /// Otro error HTTP.
    case http(Int)
}

/// Puerto del remoto con el que se sincroniza (hoy, el `db.json` que comparte con la PWA).
public protocol RemoteTrainingData: Sendable {
    func fetch() async throws(RemoteError) -> RemoteSnapshot

    /// Sube `data` encima de `revision` (`nil` = no se conoce: crear) y devuelve la revisión nueva.
    func push(_ data: TrainingData, over revision: String?, message: String) async throws(RemoteError) -> String
}

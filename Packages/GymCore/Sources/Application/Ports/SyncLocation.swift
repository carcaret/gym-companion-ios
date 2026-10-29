/// Dónde está el `db.json` que se sincroniza: un fichero de una rama de un repositorio de GitHub.
public struct SyncLocation: Hashable, Sendable {
    /// "usuario/repositorio".
    public var repository: String
    public var branch: String
    public var path: String

    /// Rama y ruta por defecto, las de la PWA.
    public static let defaultBranch = "master"
    public static let defaultPath = "db.json"

    public init(repository: String, branch: String = defaultBranch, path: String = defaultPath) {
        self.repository = repository
        self.branch = branch
        self.path = path
    }
}

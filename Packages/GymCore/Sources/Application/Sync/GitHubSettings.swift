/// Dónde está el `db.json` con el que se sincroniza (en Ajustes, como en la PWA).
public struct GitHubSettings: Hashable, Sendable {
    /// "propietario/repo".
    public var repository: String
    public var branch: String
    public var path: String

    public init(repository: String, branch: String = "master", path: String = "db.json") {
        self.repository = repository
        self.branch = branch
        self.path = path
    }

    /// El `db.json` de la PWA: repo público, así que se puede leer sin token (el primer arranque
    /// baja de aquí los datos, como hacía la PWA con su `db.json`).
    public static let pwa = GitHubSettings(repository: "carcaret/gym-companion")
}

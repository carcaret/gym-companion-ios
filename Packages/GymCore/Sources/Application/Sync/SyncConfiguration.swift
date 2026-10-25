/// Puerto del token de GitHub (un PAT). Va en el Llavero del iPhone, nunca en un fichero ni en
/// las preferencias.
public protocol CredentialStore: Sendable {
    func token() async throws -> String?
    func setToken(_ token: String?) async throws
}

/// Puerto de los ajustes de sincronización (repo, rama y ruta del `db.json`).
public protocol GitHubSettingsStore: Sendable {
    /// Sin nada guardado, `nil` (sincronización sin configurar).
    func load() async -> GitHubSettings?
    func save(_ settings: GitHubSettings?) async
}

/// Puerto: dónde se guarda el token de GitHub (en el iPhone, el Llavero; nunca en un fichero).
public protocol CredentialStore: Sendable {
    func token() async throws -> String?
    /// `nil` lo borra.
    func setToken(_ token: String?) async throws
}

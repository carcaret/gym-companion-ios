import Application
import Foundation

/// Repo, rama y ruta del `db.json` en las preferencias de la app (no son secretos; el token va
/// en el Llavero).
public struct UserDefaultsGitHubSettingsStore: GitHubSettingsStore, @unchecked Sendable {
    // UserDefaults es seguro entre hilos aunque no esté marcado como Sendable.
    private let defaults: UserDefaults
    private static let key = "github.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() async -> GitHubSettings? {
        guard let values = defaults.dictionary(forKey: Self.key) as? [String: String], let repository = values["repository"] else { return nil }
        return GitHubSettings(repository: repository, branch: values["branch"] ?? "master", path: values["path"] ?? "db.json")
    }

    public func save(_ settings: GitHubSettings?) async {
        guard let settings else { return defaults.removeObject(forKey: Self.key) }
        defaults.set(["repository": settings.repository, "branch": settings.branch, "path": settings.path], forKey: Self.key)
    }
}

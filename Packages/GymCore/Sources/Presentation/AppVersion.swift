/// Versión instalada de la app: la de marketing (`CFBundleShortVersionString`) y el número de
/// compilación (`CFBundleVersion`, el de la ejecución de GitHub Actions).
public struct AppVersion: Equatable, Sendable {
    public let marketing: String?
    public let build: String?

    public init(marketing: String?, build: String?) {
        self.marketing = marketing
        self.build = build
    }

    /// "0.1 (7)"; lo que falte, como "?".
    public var label: String {
        "\(marketing ?? "?") (\(build ?? "?"))"
    }
}

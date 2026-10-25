import Domain

/// Caso de uso del arranque: los datos guardados o, la primera vez, los iniciales (las tres
/// rutinas vacías, como la PWA), que se guardan para la próxima.
///
/// Más adelante, la primera vez se bajarán del `db.json` de GitHub (#7).
public struct StartUp: Sendable {
    private let store: any TrainingDataStore

    public init(store: any TrainingDataStore) {
        self.store = store
    }

    public func run() async throws -> TrainingData {
        if let saved = try await store.load() { return saved }
        let initial = TrainingData()
        try await store.save(initial)
        return initial
    }
}

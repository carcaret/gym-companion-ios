import Domain

/// Caso de uso del arranque: los datos guardados o, la primera vez, los de `initialSource` (el
/// `db.json` de la PWA, como hacía ella con el suyo) y, si no se pueden bajar, los iniciales (las
/// tres rutinas vacías). Lo de la primera vez se guarda para la próxima.
public struct StartUp: Sendable {
    private let store: any TrainingDataStore
    private let initialSource: (any RemoteTrainingData)?

    public init(store: any TrainingDataStore, initialSource: (any RemoteTrainingData)? = nil) {
        self.store = store
        self.initialSource = initialSource
    }

    public func run() async throws -> TrainingData {
        if let saved = try await store.load() { return saved }
        let initial = (try? await initialSource?.fetch())?.data ?? TrainingData()
        try await store.save(initial)
        return initial
    }
}

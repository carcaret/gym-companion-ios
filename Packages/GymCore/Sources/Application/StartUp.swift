import Domain

/// Caso de uso del arranque: los datos guardados o, la primera vez, los iniciales, que se
/// guardan para la próxima. Los iniciales son los de `initialData` (p. ej. los de GitHub) o, si
/// no da nada, las tres rutinas vacías, como la PWA.
public struct StartUp: Sendable {
    private let store: any TrainingDataStore
    private let initialData: @Sendable () async -> TrainingData?

    public init(store: any TrainingDataStore, initialData: @escaping @Sendable () async -> TrainingData? = { nil }) {
        self.store = store
        self.initialData = initialData
    }

    public func run() async throws -> TrainingData {
        if let saved = try await store.load() { return saved }
        let initial = await initialData() ?? TrainingData()
        try await store.save(initial)
        return initial
    }
}

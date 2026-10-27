import Application
import Domain

/// Doble del almacenamiento para los tests de casos de uso. Varias instancias creadas con el
/// mismo `Storage` ven los mismos datos, como dos arranques de la app sobre el mismo fichero.
public final class InMemoryTrainingDataStore: TrainingDataStore {
    public actor Storage {
        public private(set) var data: TrainingData?
        public private(set) var saves = 0
        /// Leer o guardar falla, como un fichero estropeado o un disco lleno.
        public private(set) var failsToLoad = false
        public private(set) var failsToSave = false

        public init(_ data: TrainingData? = nil) {
            self.data = data
        }

        public func fail(loading: Bool = false, saving: Bool = false) {
            failsToLoad = loading
            failsToSave = saving
        }

        func load() throws -> TrainingData? {
            if failsToLoad { throw Failure() }
            return data
        }

        func save(_ data: TrainingData) throws {
            if failsToSave { throw Failure() }
            self.data = data
            saves += 1
        }
    }

    public struct Failure: Error {}

    public let storage: Storage

    public init(storage: Storage = Storage()) {
        self.storage = storage
    }

    public func load() async throws -> TrainingData? {
        try await storage.load()
    }

    public func save(_ data: TrainingData) async throws {
        try await storage.save(data)
    }
}

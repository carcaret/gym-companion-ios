import Application
import Domain

/// Doble del almacenamiento para los tests de casos de uso. Varias instancias creadas con el
/// mismo `Storage` ven los mismos datos, como dos arranques de la app sobre el mismo fichero.
public final class InMemoryTrainingDataStore: TrainingDataStore {
    public actor Storage {
        public private(set) var data: TrainingData?
        public private(set) var saves = 0

        public init(_ data: TrainingData? = nil) {
            self.data = data
        }

        func save(_ data: TrainingData) {
            self.data = data
            saves += 1
        }
    }

    public let storage: Storage

    public init(storage: Storage = Storage()) {
        self.storage = storage
    }

    public func load() async throws -> TrainingData? {
        await storage.data
    }

    public func save(_ data: TrainingData) async throws {
        await storage.save(data)
    }
}

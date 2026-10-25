import Application
import Domain
import GymCoreTesting
import Testing
import ViewModels

@MainActor
private func appModel(_ store: any TrainingDataStore) -> AppModel {
    AppModel(startUp: StartUp(store: store),
             synchronizer: Synchronizer(store: store, metadataStore: InMemorySyncMetadataStore(), remote: nil, clock: FixedClock(LocalDate(year: 2026, month: 1, day: 1)!)))
}

@MainActor
@Suite("Estado de la app")
struct AppModelTests {
    @Test("al arrancar carga los datos")
    func loads() async {
        let model = appModel(InMemoryTrainingDataStore(storage: .init(TrainingDataStoreContract.sample)))
        #expect(model.data == nil)
        await model.start()
        #expect(model.data == TrainingDataStoreContract.sample)
        #expect(model.loadError == nil)
    }

    @Test("si no puede leer los datos, se queda sin datos y con el error")
    func failure() async {
        let model = appModel(FailingStore())
        await model.start()
        #expect(model.data == nil)
        #expect(model.loadError != nil)
    }

    @Test("arrancar dos veces no vuelve a cargar")
    func once() async {
        let storage = InMemoryTrainingDataStore.Storage()
        let model = appModel(InMemoryTrainingDataStore(storage: storage))
        await model.start()
        await model.start()
        #expect(await storage.saves == 1)
    }
}

private struct FailingStore: TrainingDataStore {
    struct Failure: Error {}
    func load() async throws -> TrainingData? { throw Failure() }
    func save(_ data: TrainingData) async throws {}
}

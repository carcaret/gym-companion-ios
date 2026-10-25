import Application
import Domain
import GymCoreTesting
import Testing
import ViewModels

@MainActor
@Suite("Estado de la app")
struct AppModelTests {
    @Test("al arrancar carga los datos")
    func loads() async {
        let harness = SyncHarness(local: TrainingDataStoreContract.sample, configured: false)
        let model = AppModel(repository: harness.repository())
        #expect(model.data == nil)
        await model.start()
        #expect(model.data == TrainingDataStoreContract.sample)
        #expect(model.loadError == nil)
    }

    @Test("si no puede leer los datos, se queda sin datos y con el error")
    func failure() async {
        let repository = TrainingRepository(
            store: FailingStore(), settings: InMemorySyncSettingsStore(), credentials: InMemoryCredentialStore(),
            remote: InMemoryRemote(storage: .init()), clock: FixedClock(SyncFixtures.today), background: RecordingBackgroundActivity()
        )
        let model = AppModel(repository: repository)
        await model.start()
        #expect(model.data == nil)
        #expect(model.loadError != nil)
    }

    @Test("arrancar dos veces no vuelve a cargar")
    func once() async {
        let harness = SyncHarness(local: nil, configured: false)
        let model = AppModel(repository: harness.repository())
        await model.start()
        await model.start()
        #expect(await harness.local.saves == 1)
    }

    @Test("un cambio se ve al momento y se guarda")
    func update() async {
        let harness = SyncHarness(configured: false)
        let model = AppModel(repository: harness.repository())
        await model.start()
        await model.update(SyncFixtures.finishedWorkout())
        #expect(model.data == SyncFixtures.finishedWorkout())
        #expect(await harness.savedLocally == SyncFixtures.finishedWorkout())
    }
}

private struct FailingStore: TrainingDataStore {
    struct Failure: Error {}
    func load() async throws -> TrainingData? { throw Failure() }
    func save(_ data: TrainingData) async throws {}
}

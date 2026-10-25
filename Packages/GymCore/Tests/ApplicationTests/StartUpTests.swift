import Application
import Domain
import GymCoreTesting
import Testing

@Suite("Arranque")
struct StartUpTests {
    @Test("la primera vez arranca con las tres rutinas vacías y las guarda")
    func firstLaunch() async throws {
        let storage = InMemoryTrainingDataStore.Storage()
        let data = try await StartUp(store: InMemoryTrainingDataStore(storage: storage)).run()
        #expect(data == TrainingData())
        #expect(data.routines.map(\.id) == ["DIA1", "DIA2", "DIA3"])
        #expect(try await InMemoryTrainingDataStore(storage: storage).load() == TrainingData())
    }

    @Test("después arranca con lo guardado y no lo vuelve a escribir")
    func laterLaunches() async throws {
        let storage = InMemoryTrainingDataStore.Storage(TrainingDataStoreContract.sample)
        let data = try await StartUp(store: InMemoryTrainingDataStore(storage: storage)).run()
        #expect(data == TrainingDataStoreContract.sample)
        #expect(await storage.saves == 0)
    }

    @Test("la primera vez baja los datos de la PWA, si puede")
    func firstLaunchFromRemote() async throws {
        let storage = InMemoryTrainingDataStore.Storage()
        let remote = FakeRemoteTrainingData(TrainingDataStoreContract.sample)
        let data = try await StartUp(store: InMemoryTrainingDataStore(storage: storage), initialSource: remote).run()
        #expect(data == TrainingDataStoreContract.sample)
        #expect(try await InMemoryTrainingDataStore(storage: storage).load() == TrainingDataStoreContract.sample)
    }

    @Test("la primera vez sin red arranca vacía")
    func firstLaunchOffline() async throws {
        let remote = FakeRemoteTrainingData(TrainingDataStoreContract.sample)
        await remote.failFetches(with: .unavailable)
        #expect(try await StartUp(store: InMemoryTrainingDataStore(), initialSource: remote).run() == TrainingData())
    }

    @Test("con datos guardados no baja nada")
    func noDownloadAfterwards() async throws {
        let remote = FakeRemoteTrainingData(TrainingData())
        _ = try await StartUp(store: InMemoryTrainingDataStore(storage: .init(TrainingDataStoreContract.sample)), initialSource: remote).run()
        #expect(await remote.fetches == 0)
    }

    @Test("si lo guardado no se puede leer, falla sin machacarlo")
    func unreadable() async throws {
        let store = UnreadableStore()
        await #expect(throws: UnreadableStore.Failure.self) { try await StartUp(store: store).run() }
        #expect(await store.saved == false)
    }
}

private actor UnreadableStore: TrainingDataStore {
    struct Failure: Error {}
    var saved = false

    func load() async throws -> TrainingData? { throw Failure() }
    func save(_ data: TrainingData) async throws { saved = true }
}

@Suite("Contrato del almacenamiento (doble en memoria)")
struct InMemoryContractTests {
    @Test(arguments: TrainingDataStoreContract.allCases)
    func contract(_ check: TrainingDataStoreContract) async throws {
        try await check.verify(makeStores: {
            let storage = InMemoryTrainingDataStore.Storage()
            return { InMemoryTrainingDataStore(storage: storage) }
        })
    }
}

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

    @Test("si lo guardado no se puede leer, falla sin machacarlo")
    func unreadable() async throws {
        let storage = InMemoryTrainingDataStore.Storage(TrainingDataStoreContract.sample)
        await storage.fail(loading: true)
        await #expect(throws: InMemoryTrainingDataStore.Failure.self) {
            try await StartUp(store: InMemoryTrainingDataStore(storage: storage)).run()
        }
        #expect(await storage.saves == 0)
    }
}

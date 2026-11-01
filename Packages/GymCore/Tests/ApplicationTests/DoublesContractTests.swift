import Application
import GymCoreTesting
import Testing

// Los dobles de GymCoreTesting pasan los mismos tests de contrato que los adaptadores de verdad.

@Suite("Los dobles pasan los contratos")
struct DoublesContractTests {
    @Test(arguments: TrainingDataStoreContract.allCases)
    func store(_ check: TrainingDataStoreContract) async throws {
        try await check.verify(makeStores: {
            let storage = InMemoryTrainingDataStore.Storage()
            return { InMemoryTrainingDataStore(storage: storage) }
        })
    }

    @Test(arguments: SyncSettingsStoreContract.allCases)
    func settings(_ check: SyncSettingsStoreContract) async throws {
        try await check.verify(makeStores: {
            let storage = InMemorySyncSettingsStore.Storage()
            return { InMemorySyncSettingsStore(storage: storage) }
        })
    }

    @Test(arguments: CredentialStoreContract.allCases)
    func credentials(_ check: CredentialStoreContract) async throws {
        try await check.verify(makeStores: {
            let storage = InMemoryCredentialStore.Storage()
            return { InMemoryCredentialStore(storage: storage) }
        })
    }

    @Test(arguments: RemoteTrainingDataSourceContract.allCases)
    func remote(_ check: RemoteTrainingDataSourceContract) async throws {
        try await check.verify(makeSource: {
            (InMemoryRemote(storage: .init()), SyncLocation(repository: "u/r"), "t")
        })
    }

    @Test(arguments: RemoteHealthRecordStoreContract.allCases)
    func healthRemote(_ check: RemoteHealthRecordStoreContract) async throws {
        try await check.verify(makeStore: {
            (InMemoryHealthRecordRemote(), SyncLocation(repository: "u/r", path: "salud.json"), "t")
        })
    }
}

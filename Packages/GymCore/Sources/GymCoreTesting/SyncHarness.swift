import Application
import Domain

/// El arnés con los dobles de todos los puertos, que sobreviven a "reinicios" (cada llamada a
/// `repository()` es un arranque nuevo de la app sobre los mismos datos). Los datos, `SyncFixtures`.
public struct SyncHarness: Sendable {
    public let local: InMemoryTrainingDataStore.Storage
    public let settings: InMemorySyncSettingsStore.Storage
    public let credentials: InMemoryCredentialStore.Storage
    public let remote: InMemoryRemote.Storage
    public let background = RecordingBackgroundActivity()

    /// `local: nil` = primer arranque. `configured` = repo y token guardados. `pending` = había
    /// cambios sin subir (el `needs_upload` de la PWA).
    public init(local: TrainingData? = SyncFixtures.base, remote: TrainingData? = SyncFixtures.base, remoteVersion: String = "sha_remote",
         configured: Bool = true, pending: Bool = false) {
        self.local = .init(local)
        settings = .init(SyncSettings(location: configured ? SyncFixtures.location : nil, hasPendingUpload: pending))
        credentials = .init(configured ? SyncFixtures.token : nil)
        self.remote = .init(remote, version: remoteVersion)
    }

    /// Un arranque de la app. Por defecto, la subida diferida sale en cuanto se programa.
    public func repository(uploadDelay: Duration = .zero, sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in }) -> TrainingRepository {
        TrainingRepository(
            store: InMemoryTrainingDataStore(storage: local),
            settings: InMemorySyncSettingsStore(storage: settings),
            credentials: InMemoryCredentialStore(storage: credentials),
            remote: InMemoryRemote(storage: remote),
            clock: FixedClock(SyncFixtures.today),
            background: background,
            uploadDelay: uploadDelay,
            sleep: sleep
        )
    }

    /// Un arranque cuya subida diferida no sale nunca sola (solo con `flush()`).
    public func repositoryWithoutTimer() -> TrainingRepository {
        repository(uploadDelay: .seconds(3600), sleep: { try await Task.sleep(for: $0) })
    }

    public var savedLocally: TrainingData? {
        get async { await local.data }
    }

    public var hasPendingUpload: Bool {
        get async { await settings.settings.hasPendingUpload }
    }
}

extension TrainingRepository {
    /// Espera a que termine la siguiente subida diferida.
    public func nextAutoSave() async {
        for await event in events {
            if case .autoSaved = event { return }
        }
    }
}

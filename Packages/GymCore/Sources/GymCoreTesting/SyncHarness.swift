import Application
import Domain

/// Lo común de los tests de sincronización: los datos de los e2e de la PWA (`BASE_DB`) y un
/// arnés con los dobles de todos los puertos, que sobreviven a "reinicios" (cada llamada a
/// `repository()` es un arranque nuevo de la app sobre los mismos datos).
public enum SyncFixtures {
    public static let today = LocalDate(year: 2026, month: 10, day: 25)!
    public static let location = SyncLocation(repository: "u/r", branch: "main", path: "db.json")
    public static let token = "ghp_testpat"

    public static func day(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }

    public static func pressLog(_ actual: [Int?] = [10, 10, 8], weight: Double = 60) -> ExerciseLog {
        ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: actual, weight: weight)
    }

    /// `BASE_DB` de los e2e de sincronización.
    public static let base = TrainingData(
        catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca")]),
        routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca"])],
        history: [Session(date: day("2024-01-08"), routineID: "DIA1", completed: true, logs: [pressLog()])]
    )

    public static func adding(_ session: Session, to data: TrainingData = base) -> TrainingData {
        var data = data
        data.history.append(session)
        return data
    }

    public static func adding(_ exercise: Exercise, to data: TrainingData = base) -> TrainingData {
        var data = data
        data.catalog = Catalog(data.catalog.all + [exercise])
        return data
    }

    /// El entreno de hoy en curso (empezado y quizá con algo ajustado).
    public static func activeWorkout(weight: Double = 60, actual: [Int?] = [nil, nil, nil]) -> TrainingData {
        adding(Session(date: today, routineID: "DIA1", completed: false, logs: [pressLog(actual, weight: weight)]))
    }

    /// El entreno de hoy terminado.
    public static func finishedWorkout() -> TrainingData {
        adding(Session(date: today, routineID: "DIA1", completed: true, logs: [pressLog([10, 10, 10])]))
    }
}

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

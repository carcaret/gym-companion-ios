import Application
import Domain
import GymCoreTesting
import Testing

// Portados por comportamiento de los e2e de la PWA: sync-canonicos.spec.js, github-sync.spec.js,
// workout-github-sync.spec.js y persistence.spec.js. Donde allí se miraba localStorage, aquí se
// mira el almacenamiento local; donde se interceptaba api.github.com, el remoto falso.

private let today = LocalDate(year: 2026, month: 10, day: 25)!

private func log(_ id: ExerciseID = "press_banca", weight: Double, actual: [Int?] = [10, 10, 8]) -> ExerciseLog {
    ExerciseLog(exerciseID: id, series: 3, targetReps: 10, actualReps: actual, weight: weight)
}

private func session(_ date: LocalDate, completed: Bool = true, _ logs: ExerciseLog...) -> Session {
    Session(date: date, routineID: "DIA1", completed: completed, logs: logs)
}

private func day(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }

/// `BASE_DB` de sync-canonicos.spec.js.
private let base = TrainingData(
    catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca")]),
    routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca"])],
    history: [session(day("2024-01-08"), log(weight: 60))]
)

private func adding(_ sessions: Session..., exercises: [Exercise] = [], to data: TrainingData = base) -> TrainingData {
    var copy = data
    copy.history += sessions
    copy.catalog = Catalog(copy.catalog.all + exercises)
    return copy
}

/// Entreno de hoy, terminado o en curso.
private func withWorkout(completed: Bool, weight: Double = 60, to data: TrainingData = base) -> TrainingData {
    adding(session(today, completed: completed, log(weight: weight, actual: [10, 10, 10])), to: data)
}

/// Todo lo que necesita un test: local, metadatos, remoto, `sleep` manual y el sincronizador.
private struct World {
    let local: InMemoryTrainingDataStore.Storage
    let metadata: InMemorySyncMetadataStore
    let remote: FakeRemoteTrainingData
    let sleeper = ManualSleeper()
    let sync: Synchronizer

    init(local: TrainingData? = base, metadata: SyncMetadata = SyncMetadata(), remote: TrainingData? = base, configured: Bool = true) {
        self.local = .init(local)
        self.metadata = InMemorySyncMetadataStore(metadata)
        self.remote = FakeRemoteTrainingData(remote)
        sync = Synchronizer(store: InMemoryTrainingDataStore(storage: self.local), metadataStore: self.metadata,
                            remote: configured ? self.remote : nil, clock: FixedClock(today), sleep: sleeper.sleep)
    }

    var saved: TrainingData? { get async { try? await InMemoryTrainingDataStore(storage: local).load() } }
    var pushes: Int { get async { await remote.pushes.count } }

    /// Arranca como la app: carga lo local (o los datos iniciales) y arranca la sincronización.
    func startApp() async throws -> TrainingData {
        let data = try await StartUp(store: InMemoryTrainingDataStore(storage: local)).run()
        await sync.start(with: data)
        return data
    }

    /// Lo que aún no ha llegado del flujo de eventos.
    func drainEvents() async -> [SyncEvent] {
        let stream = sync.events
        let task = Task {
            var events: [SyncEvent] = []
            for await event in stream { events.append(event) }
            return events
        }
        for _ in 0..<20 { await Task.yield() }
        task.cancel()
        return await task.value
    }
}

private func remoteApplied(_ events: [SyncEvent]) -> Bool {
    events.contains { if case .remoteApplied = $0 { true } else { false } }
}

@Suite("Canónicos de resiliencia — opción B estricta")
struct SyncCanonicalTests {
    @Test("Canónico A: entreno completado con GitHub caído → persiste en local y se sube al reload")
    func canonicalA() async throws {
        let world = World()
        await world.remote.failFetches(with: .unavailable)
        await world.remote.failPushes(with: .unavailable)
        _ = try await world.startApp()
        try await world.sync.save(withWorkout(completed: true))
        await world.sync.uploadNow()
        #expect(await world.saved?.history.session(on: today)?.completed == true)
        #expect(await world.sync.status == .pending)

        // "Recarga" con GitHub de vuelta: otro sincronizador sobre los mismos datos.
        await world.remote.failFetches(with: nil)
        await world.remote.failPushes(with: nil)
        let pushesBefore = await world.pushes
        let restarted = Synchronizer(store: InMemoryTrainingDataStore(storage: world.local), metadataStore: world.metadata,
                                     remote: world.remote, clock: FixedClock(today), sleep: world.sleeper.sleep)
        await restarted.start(with: try #require(await world.saved))
        #expect(await restarted.status == .ok)
        #expect(await world.saved?.history.session(on: today)?.completed == true)
        #expect(await world.pushes > pushesBefore)
    }

    @Test("Canónico C: needsUpload=true + remote diferente → local intacto al arrancar")
    func canonicalC() async throws {
        let local = adding(session(day("2024-03-01"), log(weight: 65, actual: [9, 9, 9])))
        var remote = base
        remote.history = [session(day("2024-01-08"), log(weight: 40, actual: [5, 5, 5]))]
        let world = World(local: local, metadata: SyncMetadata(needsUpload: true), remote: remote)
        _ = try await world.startApp()
        let after = try #require(await world.saved)
        #expect(after.history.contains { $0.date == day("2024-03-01") })
        #expect(after.history.session(on: day("2024-01-08"))?.logs[0].weight == 60)
    }

    @Test("Canónico B: botón \"Sincronizar desde GitHub\" sobreescribe local con remote tras confirmación")
    func canonicalB() async throws {
        var remote = base
        remote.catalog = Catalog(base.catalog.all + [Exercise(id: "dominadas", name: "Dominadas")])
        remote.history = [session(day("2024-02-14"))]
        let world = World(remote: remote)
        _ = try await world.startApp()
        try await world.sync.save(adding(session(day("2024-03-03"))))  // algo local sin subir
        let result = await world.sync.downloadRemote()
        #expect(try result.get() == remote)
        let after = try #require(await world.saved)
        #expect(after.catalog.ids.contains("dominadas"))
        #expect(after.history.contains { $0.date == day("2024-02-14") })
        #expect(!after.history.contains { $0.date == day("2024-01-08") })
        #expect(await world.metadata.metadata.needsUpload == false)
    }

    @Test("Canónico D: 409 en PUT → indicador pendiente → modal con 3 opciones")
    func canonicalD() async throws {
        let world = World()
        _ = try await world.startApp()
        await world.remote.set(adding(session(day("2024-06-01"))), revision: "sha_editado_a_mano")
        try await world.sync.save(withWorkout(completed: true))
        #expect(await world.sync.uploadNow() == .conflict)
        // El indicador (ver SyncIndicatorTests) muestra pendiente y abre las opciones del conflicto.
        #expect(await world.sync.status == .conflict)
        // Mientras no se elija, no se vuelve a intentar.
        await world.sync.retryIfPending()
        #expect(await world.pushes == 1)
    }

    @Test("Canónico E: arranque con needsUpload=false → indicador \"ok\", sin PUT")
    func canonicalE() async throws {
        let world = World(metadata: SyncMetadata(needsUpload: false))
        _ = try await world.startApp()
        #expect(await world.sync.status == .ok)
        #expect(await world.pushes == 0)
    }

    @Test("Canónico F: arranque needsUpload=false + remote==local → GET ocurre, sin toast, sin PUT, local intacto")
    func canonicalF() async throws {
        let world = World(remote: base)
        _ = try await world.startApp()
        #expect(await world.remote.fetches > 0)
        #expect(await world.pushes == 0)
        #expect(!remoteApplied(await world.drainEvents()))
        #expect(await world.saved == base)
        // La revisión queda apuntada: la siguiente subida no da conflicto.
        #expect(await world.metadata.metadata.revision == "sha_remote")
    }

    @Test("Canónico G: arranque needsUpload=false + remote≠local → local sobreescrito + toast")
    func canonicalG() async throws {
        let remote = adding(session(day("2024-05-20")), exercises: [Exercise(id: "dominadas", name: "Dominadas")])
        let world = World(remote: remote)
        let events = Task { () -> Bool in
            for await event in world.sync.events { if case .remoteApplied = event { return true } }
            return false
        }
        _ = try await world.startApp()
        let after = try #require(await world.saved)
        #expect(after.catalog.ids.contains("dominadas"))
        #expect(after.history.contains { $0.date == day("2024-05-20") })
        #expect(await world.metadata.metadata.needsUpload == false)
        #expect(await world.pushes == 0)
        #expect(await events.value)
    }

    @Test("Canónico H: arranque needsUpload=true + remote≠local → NO se sobreescribe")
    func canonicalH() async throws {
        let local = adding(session(day("2024-04-10")))
        let world = World(local: local, metadata: SyncMetadata(needsUpload: true), remote: adding(session(day("2024-05-20"))))
        _ = try await world.startApp()
        #expect(await world.saved?.history.contains { $0.date == day("2024-04-10") } == true)
    }

    @Test("Canónico I: arranque con entreno activo + remote≠local → NO se sobreescribe")
    func canonicalI() async throws {
        let local = withWorkout(completed: false)
        let world = World(local: local, remote: adding(session(day("2024-05-20")), exercises: [Exercise(id: "remo", name: "Remo")]))
        _ = try await world.startApp()
        let after = try #require(await world.saved)
        #expect(after.history.session(on: today)?.completed == false)
        #expect(!after.catalog.ids.contains("remo"))
    }

    @Test("Canónico J: edit local durante el fetch → pull aborta, local sobrevive")
    func canonicalJ() async throws {
        let world = World(remote: adding(session(day("2024-05-20"))))
        let edited = adding(session(day("2024-06-06")), exercises: [Exercise(id: "local_only", name: "Solo local")])
        let sync = world.sync
        await world.remote.onFetch { try? await sync.save(edited) }
        _ = try await world.startApp()
        #expect(await world.saved?.catalog.ids.contains("local_only") == true)
    }

    @Test("Canónico K: GitHub inaccesible al arrancar → local intacto, sin toast de error")
    func canonicalK() async throws {
        let world = World()
        await world.remote.failFetches(with: .unavailable)
        _ = try await world.startApp()
        #expect(await world.saved == base)
        // Sin aviso: el estado sigue en ok (no había nada que subir).
        #expect(await world.sync.status == .ok)
    }

    @Test("Canónico L: GitHub 404 al arrancar → local intacto")
    func canonicalL() async throws {
        let world = World()
        await world.remote.failFetches(with: .notFound)
        _ = try await world.startApp()
        #expect(await world.saved == base)
    }

    @Test("Canónico M: needsUpload=true sin sha → GET pobla sha antes del PUT")
    func canonicalM() async throws {
        let world = World(metadata: SyncMetadata(needsUpload: true, revision: nil))
        await world.remote.set(base, revision: "sha_from_get")
        _ = try await world.startApp()
        #expect(await world.sync.status == .ok)
        #expect(await world.remote.fetches == 1)
        #expect(await world.remote.pushes.first?.over == "sha_from_get")
    }

    @Test("Canónico N: sin sha + GET falla → no hay PUT, queda en pending")
    func canonicalN() async throws {
        let world = World(metadata: SyncMetadata(needsUpload: true, revision: nil))
        await world.remote.failFetches(with: .unavailable)
        _ = try await world.startApp()
        #expect(await world.sync.status == .pending)
        #expect(await world.pushes == 0)
    }
}

@Suite("GitHub sync (mock)")
struct GitHubSyncTests {
    @Test("guardar datos intercepta PUT a api.github.com al finalizar entreno")
    func putOnFinish() async throws {
        let world = World()
        _ = try await world.startApp()
        try await world.sync.save(withWorkout(completed: true))
        #expect(await world.sync.uploadNow() == .done)
        let push = try #require(await world.remote.pushes.last)
        #expect(push.data.history.session(on: today)?.completed == true)
        #expect(push.message == "Gym Companion update 2026-10-25")
        #expect(await world.metadata.metadata.needsUpload == false)
    }

    @Test("GitHub devuelve 401 → muestra mensaje de error")
    func unauthorized() async throws {
        let world = World()
        _ = try await world.startApp()
        await world.remote.failPushes(with: .unauthorized)
        try await world.sync.save(withWorkout(completed: true))
        #expect(await world.sync.uploadNow() == .failed(.unauthorized))
        #expect(await world.sync.status == .pending)
    }

    @Test("sin conexión (fetch falla) → datos locales se mantienen")
    func offline() async throws {
        let world = World()
        await world.remote.failFetches(with: .unavailable)
        await world.remote.failPushes(with: .unavailable)
        _ = try await world.startApp()
        try await world.sync.save(withWorkout(completed: true))
        await world.sync.uploadNow()
        #expect(await world.saved == withWorkout(completed: true))
        #expect(await world.metadata.metadata.needsUpload)
    }

    @Test("GitHub devuelve 409 (conflicto en save) → datos locales se conservan")
    func conflictKeepsLocal() async throws {
        let world = World()
        _ = try await world.startApp()
        await world.remote.failPushes(with: .conflict)
        try await world.sync.save(withWorkout(completed: true))
        await world.sync.uploadNow()
        #expect(await world.saved == withWorkout(completed: true))
        #expect(await world.sync.status == .conflict)
    }
}

@Suite("GitHub sync durante entreno activo")
struct WorkoutSyncTests {
    @Test("iniciar entreno NO dispara PUT a GitHub")
    func start() async throws {
        let world = World()
        _ = try await world.startApp()
        try await world.sync.save(withWorkout(completed: false))
        await world.sleeper.advance()
        #expect(await world.pushes == 0)
        #expect(await world.sleeper.sleepers == 0)
    }

    @Test("ajustar peso durante entreno NO dispara PUT a GitHub")
    func adjustWeight() async throws {
        let world = World()
        _ = try await world.startApp()
        try await world.sync.save(withWorkout(completed: false, weight: 60))
        try await world.sync.save(withWorkout(completed: false, weight: 65))
        await world.sleeper.advance()
        #expect(await world.pushes == 0)
        #expect(await world.saved?.history.session(on: today)?.logs[0].weight == 65)
    }

    @Test("ajustar reps durante entreno NO dispara PUT a GitHub")
    func adjustReps() async throws {
        let world = World()
        _ = try await world.startApp()
        var data = withWorkout(completed: false)
        data.history[data.history.count - 1].logs[0].adjustRep(at: 0, by: 1)
        try await world.sync.save(data)
        await world.sleeper.advance()
        #expect(await world.pushes == 0)
    }

    @Test("finalizar entreno SÍ dispara PUT a GitHub")
    func finish() async throws {
        let world = World()
        _ = try await world.startApp()
        try await world.sync.save(withWorkout(completed: false))
        try await world.sync.save(withWorkout(completed: true))
        await world.sync.uploadNow()
        #expect(await world.pushes == 1)
    }

    @Test("múltiples ajustes durante entreno → 0 PUTs, finalizar → 1 PUT")
    func manyAdjustments() async throws {
        let world = World()
        _ = try await world.startApp()
        for weight in stride(from: 60.0, through: 70, by: 2.5) { try await world.sync.save(withWorkout(completed: false, weight: weight)) }
        await world.sleeper.advance()
        #expect(await world.pushes == 0)
        try await world.sync.save(withWorkout(completed: true, weight: 70))
        await world.sync.uploadNow()
        await world.sleeper.advance()
        #expect(await world.pushes == 1)
    }
}

@Suite("Persistencia y datos")
struct PersistenceTests {
    @Test("app arranca → recarga → datos intactos")
    func reload() async throws {
        let world = World(local: nil, remote: nil, configured: false)
        let first = try await world.startApp()
        try await world.sync.save(adding(session(day("2026-10-20")), to: first))
        let second = try await world.startApp()
        #expect(second == adding(session(day("2026-10-20")), to: first))
    }

    @Test("iniciar entreno → ajustar peso → verificar en DB")
    func adjustAndCheck() async throws {
        let world = World()
        _ = try await world.startApp()
        try await world.sync.save(withWorkout(completed: false, weight: 62.5))
        #expect(await world.saved?.history.session(on: today)?.logs[0].weight == 62.5)
    }

    @Test("localStorage tiene DB_LOCAL_KEY con datos válidos")
    func localData() async throws {
        let world = World(local: nil, remote: nil, configured: false)
        _ = try await world.startApp()
        let saved = try #require(await world.saved)
        #expect(saved.routines.map(\.id) == ["DIA1", "DIA2", "DIA3"])
    }
}

@Suite("Subida con retraso")
struct DebounceTests {
    @Test("fuera de un entreno, varios cambios seguidos suben una sola vez, con lo último")
    func coalesces() async throws {
        let world = World()
        _ = try await world.startApp()
        try await world.sync.save(adding(session(day("2026-10-20"))))
        try await world.sync.save(adding(session(day("2026-10-21"))))
        #expect(await world.pushes == 0)
        await world.sleeper.advance()
        #expect(await world.pushes == 1)
        #expect(await world.remote.pushes.last?.data == adding(session(day("2026-10-21"))))
        #expect(await world.sync.status == .ok)
    }

    @Test("al ir a segundo plano se sube lo que esperaba, sin esperar el retraso")
    func flush() async throws {
        let world = World()
        _ = try await world.startApp()
        try await world.sync.save(adding(session(day("2026-10-20"))))
        await world.sync.flush()
        #expect(await world.pushes == 1)
        await world.sleeper.advance()
        #expect(await world.pushes == 1)
    }

    @Test("sin GitHub configurado se guarda en local y no se intenta subir")
    func notConfigured() async throws {
        let world = World(configured: false)
        _ = try await world.startApp()
        try await world.sync.save(adding(session(day("2026-10-20"))))
        await world.sleeper.advance()
        #expect(await world.sync.status == .disabled)
        #expect(await world.pushes == 0)
        #expect(await world.sync.uploadNow() == .notConfigured)
    }

    @Test("al volver la red se reintenta lo pendiente")
    func retry() async throws {
        let world = World()
        _ = try await world.startApp()
        await world.remote.failPushes(with: .unavailable)
        try await world.sync.save(adding(session(day("2026-10-20"))))
        await world.sleeper.advance()
        #expect(await world.sync.status == .pending)
        await world.remote.failPushes(with: nil)
        await world.sync.retryIfPending()
        #expect(await world.sync.status == .ok)
        #expect(await world.metadata.metadata.needsUpload == false)
    }
}

@Suite("Conflicto")
struct ConflictResolutionTests {
    private func inConflict() async throws -> World {
        let world = World()
        _ = try await world.startApp()
        await world.remote.set(adding(session(day("2024-06-01"))), revision: "sha_editado_a_mano")
        try await world.sync.save(withWorkout(completed: true))
        await world.sync.uploadNow()
        return world
    }

    @Test("Subir local → GitHub: sube encima de lo que haya")
    func keepLocal() async throws {
        let world = try await inConflict()
        #expect(await world.sync.keepLocal() == .done)
        #expect(await world.remote.snapshot?.data == withWorkout(completed: true))
        #expect(await world.sync.status == .ok)
    }

    @Test("Bajar GitHub → local: lo de GitHub sustituye a lo local")
    func takeRemote() async throws {
        let world = try await inConflict()
        _ = await world.sync.downloadRemote()
        #expect(await world.saved == adding(session(day("2024-06-01"))))
        #expect(await world.sync.status == .ok)
    }

    @Test("con conflicto, Subir a GitHub no sube: abre el conflicto")
    func manualUploadWithConflict() async throws {
        let world = try await inConflict()
        #expect(await world.sync.uploadNow() == .conflict)
        #expect(await world.pushes == 1)
    }
}

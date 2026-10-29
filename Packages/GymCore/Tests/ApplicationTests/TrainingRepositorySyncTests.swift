import Application
import Domain
import GymCoreTesting
import Testing

// Port por comportamiento de los e2e de sincronización de la PWA: cada @Suite es un `describe`
// y cada @Test, un `test` con el mismo nombre. Lo que en la PWA es "interceptar el PUT" aquí es
// contar las subidas del doble del remoto; lo que es localStorage, el doble del almacenamiento.

private typealias F = SyncFixtures

// tests/e2e/github-sync.spec.js
@Suite("GitHub sync (mock)", .timeLimit(.minutes(1)))
struct GitHubSyncTests {
    @Test("guardar datos intercepta PUT a api.github.com al finalizar entreno")
    func putOnFinish() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()

        // Durante el entreno no se sube nada.
        try await repository.update(F.activeWorkout())
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)

        #expect(try await repository.saveAndUpload(F.finishedWorkout()) == .uploaded)
        #expect(await repository.status == SyncStatus(state: .ok, conflict: false))
        let push = try #require(await harness.remote.pushes.first)
        #expect(push.data == F.finishedWorkout())
        #expect(push.day == F.today)
    }

    @Test("GitHub devuelve 401 → muestra mensaje de error")
    func unauthorized() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .unauthorized, push: .unauthorized)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.download() == .failed)
    }

    @Test("sin conexión (fetch falla) → datos locales se mantienen")
    func offline() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.download() == .failed)
        #expect(await harness.savedLocally == F.base)
        #expect(await repository.data == F.base)
    }

    @Test("GitHub devuelve 409 (conflicto en save) → datos locales se conservan")
    func conflictKeepsLocal() async throws {
        let harness = SyncHarness(remote: nil)
        await harness.remote.fail(push: .conflict)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        #expect(await harness.savedLocally?.history.count == 2)
    }
}

// tests/e2e/sync-canonicos.spec.js
@Suite("Canónicos de resiliencia — opción B estricta", .timeLimit(.minutes(1)))
struct SyncCanonicalTests {
    @Test("Canónico A: entreno completado con GitHub caído → persiste en local y se sube al reload")
    func canonicalA() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        let first = harness.repository()
        _ = try await first.start()
        #expect(try await first.saveAndUpload(F.finishedWorkout()) == .unreachable)
        let saved = try #require(await harness.savedLocally?.history.session(on: F.today))
        #expect(saved.completed)

        // Segundo arranque, con GitHub de vuelta: lo pendiente se sube.
        await harness.remote.fail()
        let second = harness.repository()
        _ = try await second.start()
        #expect(await second.synchronize() == .uploaded)
        #expect(await second.status.state == .ok)
        #expect(await second.data.history.session(on: F.today)?.completed == true)
        #expect(await harness.remote.pushes.count > 0)
    }

    @Test("Canónico C: needsUpload=true + remote diferente → local intacto al arrancar")
    func canonicalC() async throws {
        let local = F.adding(Session(date: F.day("2024-03-01"), routineID: "DIA1", completed: true, logs: [F.pressLog([9, 9, 9], weight: 65)]))
        var remote = F.base
        remote.history = [Session(date: F.day("2024-01-08"), routineID: "DIA1", completed: true, logs: [F.pressLog([5, 5, 5], weight: 40)])]
        let harness = SyncHarness(local: local, remote: remote, pending: true)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = await repository.synchronize()

        let after = try #require(await harness.savedLocally)
        #expect(after.history.contains { $0.date == F.day("2024-03-01") })
        #expect(after.history.session(on: F.day("2024-01-08"))?.logs[0].weight == 60)
    }

    @Test("Canónico B: botón \"Sincronizar desde GitHub\" sobreescribe local con remote tras confirmación")
    func canonicalB() async throws {
        var remote = F.adding(Exercise(id: "dominadas", name: "Dominadas"))
        remote.history = [Session(date: F.day("2024-02-14"), routineID: "DIA1", completed: true)]
        let harness = SyncHarness(remote: remote, pending: true)
        let repository = harness.repository()
        _ = try await repository.start()

        #expect(await repository.download() == .applied(remote))
        let after = try #require(await harness.savedLocally)
        #expect(after.catalog.ids.contains("dominadas"))
        #expect(after.history.contains { $0.date == F.day("2024-02-14") })
        #expect(!after.history.contains { $0.date == F.day("2024-01-08") })
        #expect(await harness.hasPendingUpload == false)
    }

    @Test("Canónico D: 409 en PUT → indicador pendiente → modal con 3 opciones")
    func canonicalD() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(try await repository.saveAndUpload(F.finishedWorkout()) == .conflict)
        #expect(await repository.status == SyncStatus(state: .pending, conflict: true))
    }

    @Test("Canónico E: arranque con needsUpload=false → indicador \"ok\", sin PUT")
    func canonicalE() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.status.state == .ok)
        _ = await repository.synchronize()
        #expect(await repository.status.state == .ok)
        #expect(await harness.remote.pushes.isEmpty)
    }

    @Test("Canónico F: arranque needsUpload=false + remote==local → GET ocurre, sin toast, sin PUT, local intacto")
    func canonicalF() async throws {
        let harness = SyncHarness(remoteVersion: "sha_remote_match")
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.synchronize() == .nothing)
        #expect(await harness.remote.fetches > 0)
        #expect(await harness.remote.pushes.isEmpty)
        #expect(await harness.savedLocally == F.base)

        // El sha queda guardado: la siguiente subida no necesita otro GET y no da un 422 espurio.
        let fetches = await harness.remote.fetches
        #expect(try await repository.saveAndUpload(F.finishedWorkout()) == .uploaded)
        #expect(await harness.remote.fetches == fetches)
        #expect(await harness.remote.pushes.first?.replacing == RemoteVersion("sha_remote_match"))
    }

    @Test("Canónico G: arranque needsUpload=false + remote≠local → local sobreescrito + toast")
    func canonicalG() async throws {
        let remote = F.adding(Session(date: F.day("2024-05-20"), routineID: "DIA1", completed: true, logs: [F.pressLog([10, 10, 10], weight: 70)]),
                              to: F.adding(Exercise(id: "dominadas", name: "Dominadas")))
        let harness = SyncHarness(remote: remote)
        let repository = harness.repository()
        _ = try await repository.start()

        #expect(await repository.synchronize() == .remoteApplied(remote))
        let after = try #require(await harness.savedLocally)
        #expect(after.catalog.ids.contains("dominadas"))
        #expect(after.history.contains { $0.date == F.day("2024-05-20") })
        #expect(await harness.hasPendingUpload == false)
        #expect(await harness.remote.pushes.isEmpty)
    }

    @Test("Canónico H: arranque needsUpload=true + remote≠local → NO se sobreescribe")
    func canonicalH() async throws {
        let local = F.adding(Session(date: F.day("2024-04-10"), routineID: "DIA1", completed: true, logs: [F.pressLog([8, 8, 8], weight: 55)]))
        let harness = SyncHarness(local: local, pending: true)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = await repository.synchronize()
        #expect(await harness.savedLocally?.history.contains { $0.date == F.day("2024-04-10") } == true)
    }

    @Test("Canónico I: arranque con entreno activo + remote≠local → NO se sobreescribe")
    func canonicalI() async throws {
        let local = F.activeWorkout(weight: 50, actual: [10, nil, nil])
        let harness = SyncHarness(local: local, remote: F.adding(Exercise(id: "remo", name: "Remo")))
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.synchronize() == .nothing)

        let after = try #require(await harness.savedLocally)
        #expect(after.history.session(on: F.today)?.completed == false)
        #expect(!after.catalog.ids.contains("remo"))
    }

    @Test("Canónico J: edit local durante el fetch → pull aborta, local sobrevive")
    func canonicalJ() async throws {
        let local = F.adding(Exercise(id: "local_only", name: "Local Only"))
        let harness = SyncHarness(local: local, remote: F.base)
        let repository = harness.repositoryWithoutTimer()
        _ = try await repository.start()

        await harness.remote.holdFetches()
        let pull = Task { await repository.synchronize() }
        await harness.remote.waitForHeldFetch()
        // Mientras el GET está en vuelo, el usuario edita.
        var edited = local
        edited.routines[0].exerciseIDs.append("local_only")
        try await repository.update(edited)
        await harness.remote.releaseFetches()

        #expect(await pull.value == .nothing)
        #expect(await harness.savedLocally?.catalog.ids.contains("local_only") == true)
        #expect(await repository.data == edited)
    }

    @Test("Canónico K: GitHub inaccesible al arrancar → local intacto, sin toast de error")
    func canonicalK() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.synchronize() == .nothing)
        #expect(await harness.savedLocally == F.base)
    }

    @Test("Canónico L: GitHub 404 al arrancar → local intacto")
    func canonicalL() async throws {
        let harness = SyncHarness(remote: nil)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.synchronize() == .nothing)
        #expect(await harness.savedLocally == F.base)
    }

    @Test("Canónico M: needsUpload=true sin sha → GET pobla sha antes del PUT")
    func canonicalM() async throws {
        let harness = SyncHarness(remoteVersion: "sha_from_get", pending: true)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.synchronize() == .uploaded)
        #expect(await repository.status.state == .ok)
        #expect(await harness.remote.fetches == 1)
        #expect(await harness.remote.pushes.first?.replacing == RemoteVersion("sha_from_get"))
    }

    @Test("Canónico N: sin sha + GET falla → no hay PUT, queda en pending")
    func canonicalN() async throws {
        let harness = SyncHarness(pending: true)
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.synchronize() == .failed)
        #expect(await repository.status.state == .pending)
        #expect(await harness.remote.pushAttempts == 0)
    }
}

// tests/e2e/workout-github-sync.spec.js. "No dispara PUT" se comprueba con `flush()`, que solo
// sube si hay una subida programada.
@Suite("GitHub sync durante entreno activo", .timeLimit(.minutes(1)))
struct WorkoutSyncTests {
    @Test("iniciar entreno NO dispara PUT a GitHub")
    func start() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)
    }

    @Test("ajustar peso durante entreno NO dispara PUT a GitHub")
    func weight() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        try await repository.update(F.activeWorkout(weight: 62.5))
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)
        let today = try #require(await harness.savedLocally?.history.session(on: F.today))
        #expect(today.completed == false)
        #expect(today.logs[0].weight == 62.5)
    }

    @Test("ajustar reps durante entreno NO dispara PUT a GitHub")
    func reps() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        try await repository.update(F.activeWorkout(actual: [12, nil, nil]))
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)
    }

    @Test("finalizar entreno SÍ dispara PUT a GitHub")
    func finish() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)
        #expect(try await repository.saveAndUpload(F.finishedWorkout()) == .uploaded)
        #expect(await repository.status.state == .ok)
        #expect(await harness.remote.pushes.count == 1)
    }

    @Test("múltiples ajustes durante entreno → 0 PUTs, finalizar → 1 PUT")
    func many() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        try await repository.update(F.activeWorkout(weight: 62.5))
        try await repository.update(F.activeWorkout(weight: 65))
        try await repository.update(F.activeWorkout(weight: 65, actual: [8, nil, nil]))
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        #expect(await repository.status.state == .ok)
        #expect(await harness.remote.pushes.count == 1)
    }
}

// tests/e2e/persistence.spec.js (la parte de datos; lo que se ve en Historial, en #10).
@Suite("Persistencia y datos", .timeLimit(.minutes(1)))
struct PersistenceTests {
    @Test("app arranca → recarga → datos intactos")
    func reload() async throws {
        let harness = SyncHarness(configured: false)
        let first = try await harness.repository().start()
        let second = try await harness.repository().start()
        #expect(first == F.base)
        #expect(second == first)
    }

    @Test("iniciar entreno → ajustar peso → verificar en DB")
    func weight() async throws {
        let harness = SyncHarness(configured: false)
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout(weight: 62.5))
        #expect(await harness.savedLocally?.history.session(on: F.today)?.logs[0].weight == 62.5)
    }

    @Test("localStorage tiene DB_LOCAL_KEY con datos válidos")
    func savedData() async throws {
        let harness = SyncHarness(local: nil, configured: false)
        _ = try await harness.repository().start()
        // El primer arranque sin GitHub guarda los datos iniciales.
        #expect(await harness.savedLocally == TrainingData())
    }

    @Test("finalizar entreno → historial muestra entry con datos correctos")
    func finish() async throws {
        let harness = SyncHarness(configured: false)
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        #expect(try await repository.saveAndUpload(F.finishedWorkout()) == .notConfigured)
        let today = try #require(await harness.savedLocally?.history.session(on: F.today))
        #expect(today.completed)
        #expect(today.logs.map(\.exerciseID) == ["press_banca"])
    }
}

// tests/unit/keepalive.test.js, por intención: lo pendiente no se pierde al ir a segundo plano.
// El `keepalive` del fetch de la PWA es aquí pedir tiempo en segundo plano (`BackgroundActivity`)
// para la subida que `flush()` adelanta; las demás subidas no lo piden.
@Suite("keepalive fetch option", .timeLimit(.minutes(1)))
struct KeepaliveTests {
    @Test("sin options → no tiene keepalive")
    func plainUpload() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(try await repository.saveAndUpload(F.finishedWorkout()) == .uploaded)
        #expect(await harness.background.runs == 0)
    }

    @Test("con keepalive: true → fetch incluye keepalive")
    func flushKeepsAlive() async throws {
        let harness = SyncHarness()
        let repository = harness.repositoryWithoutTimer()
        _ = try await repository.start()
        try await repository.update(F.finishedWorkout())
        #expect(await harness.remote.pushes.isEmpty)
        await repository.flush()
        #expect(await harness.remote.pushes.count == 1)
        #expect(await harness.background.runs == 1)
        #expect(await harness.hasPendingUpload == false)
    }

    @Test("con keepalive: false → no incluye keepalive")
    func scheduledUpload() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.finishedWorkout())
        await repository.nextAutoSave()
        #expect(await harness.remote.pushes.count == 1)
        #expect(await harness.background.runs == 0)
    }

    @Test("con options vacío → no tiene keepalive")
    func nothingToFlush() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)
        #expect(await harness.background.runs == 0)
    }
}

// Propio de la app: el indicador distingue lo que espera al final del entreno (lo normal) de lo
// que no se ha podido subir.
@Suite("Pendiente a la espera del entreno", .timeLimit(.minutes(1)))
struct WaitingForWorkoutTests {
    @Test("con un entreno en curso, lo pendiente espera a que acabe")
    func waitsDuringWorkout() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        #expect(await repository.status == SyncStatus(state: .pending, waitingForWorkout: true))
    }

    @Test("al terminar el entreno deja de esperar, se suba o no")
    func finishing() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.activeWorkout())
        await harness.remote.fail(push: .unreachable)
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        #expect(await repository.status == SyncStatus(state: .pending, waitingForWorkout: false))
        await harness.remote.fail()
        #expect(await repository.synchronize() == .uploaded)
        #expect(await repository.status == SyncStatus(state: .ok))
    }

    @Test("sin entreno en curso, lo pendiente no espera a nada")
    func pendingWithoutWorkout() async throws {
        let harness = SyncHarness(pending: true)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.status == SyncStatus(state: .pending, waitingForWorkout: false))
    }
}

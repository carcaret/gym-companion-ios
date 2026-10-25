import Application
import Domain
import GymCoreTesting
import Testing

private typealias F = SyncFixtures

/// Lo que la app añade a la política de la PWA, o lo que la PWA hacía sin test.
@Suite("Repositorio de datos con sincronización", .timeLimit(.minutes(1)))
struct TrainingRepositoryTests {
    @Test("sin GitHub configurado, el indicador está desactivado y no se toca la red")
    func disabled() async throws {
        let harness = SyncHarness(configured: false)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.status == SyncStatus(state: .disabled, conflict: false))
        #expect(await repository.synchronize() == .nothing)
        try await repository.update(F.finishedWorkout())
        await repository.flush()
        #expect(await harness.remote.fetches == 0)
        #expect(await harness.remote.pushAttempts == 0)
        #expect(await repository.status.state == .disabled)
    }

    @Test("con cambios pendientes, el indicador arranca en pendiente")
    func startsPending() async throws {
        let harness = SyncHarness(pending: true)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.status.state == .pending)
    }

    @Test("el primer arranque con GitHub configurado baja los datos de GitHub")
    func firstLaunchDownloads() async throws {
        let harness = SyncHarness(local: nil, remote: F.finishedWorkout())
        let data = try await harness.repository().start()
        #expect(data == F.finishedWorkout())
        #expect(await harness.savedLocally == F.finishedWorkout())
    }

    @Test("el primer arranque sin poder bajar de GitHub arranca con los datos iniciales")
    func firstLaunchOffline() async throws {
        let harness = SyncHarness(local: nil)
        await harness.remote.fail(fetch: .unreachable)
        #expect(try await harness.repository().start() == TrainingData())
    }

    @Test("varios cambios seguidos se suben de una vez")
    func debounce() async throws {
        let harness = SyncHarness()
        let repository = harness.repositoryWithoutTimer()
        _ = try await repository.start()
        try await repository.update(F.adding(Exercise(id: "a", name: "A")))
        try await repository.update(F.adding(Exercise(id: "b", name: "B")))
        try await repository.update(F.finishedWorkout())
        await repository.flush()
        #expect(await harness.remote.pushes.map(\.data) == [F.finishedWorkout()])
    }

    @Test("una subida diferida que se cancela con un cambio nuevo no sale dos veces")
    func rescheduling() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.adding(Exercise(id: "a", name: "A")))
        await repository.nextAutoSave()
        try await repository.update(F.finishedWorkout())
        await repository.nextAutoSave()
        #expect(await harness.remote.pushes.last?.data == F.finishedWorkout())
        #expect(await harness.hasPendingUpload == false)
    }

    @Test("un cambio mientras se sube sigue pendiente: no se marca como subido lo que no se subió")
    func editDuringUpload() async throws {
        let harness = SyncHarness()
        let repository = harness.repositoryWithoutTimer()
        _ = try await repository.start()
        await harness.remote.holdPushes()
        let upload = Task { try await repository.saveAndUpload(F.finishedWorkout()) }
        await harness.remote.waitForHeldPush()
        let edited = F.adding(Exercise(id: "nuevo", name: "Nuevo"), to: F.finishedWorkout())
        try await repository.update(edited)
        await harness.remote.releasePushes()

        #expect(try await upload.value == .uploaded)
        #expect(await harness.hasPendingUpload)
        #expect(await repository.status.state == .pending)
        await repository.flush()
        #expect(await harness.remote.pushes.last?.data == edited)
        #expect(await harness.hasPendingUpload == false)
    }

    @Test("dos subidas a la vez van una detrás de otra, sin falso conflicto")
    func serialUploads() async throws {
        let harness = SyncHarness()
        let repository = harness.repositoryWithoutTimer()
        _ = try await repository.start()
        try await repository.update(F.finishedWorkout())
        async let first = repository.forceUpload()
        async let second = repository.forceUpload()
        #expect(await [first, second] == [.uploaded, .uploaded])
        #expect(await repository.status == SyncStatus(state: .ok, conflict: false))
    }

    // MARK: - Botones de Ajustes y del conflicto

    @Test("Subir a GitHub sin configurar no toca la red")
    func forceUploadNotConfigured() async throws {
        let harness = SyncHarness(configured: false)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.forceUpload() == .notConfigured)
        #expect(await harness.remote.pushAttempts == 0)
    }

    @Test("Subir a GitHub con un conflicto abierto no sube: hay que resolverlo")
    func forceUploadWithConflict() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        let attempts = await harness.remote.pushAttempts
        #expect(await repository.forceUpload() == .conflict)
        #expect(await harness.remote.pushAttempts == attempts)
    }

    @Test("conflicto → Subir local: baja el sha actual y machaca GitHub con lo local")
    func keepLocal() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        // Alguien editó db.json a mano.
        await harness.remote.fail()
        await harness.remote.replace(with: F.adding(Exercise(id: "a_mano", name: "A mano")), version: "sha_a_mano")

        #expect(await repository.keepLocal() == .uploaded)
        #expect(await repository.status == SyncStatus(state: .ok, conflict: false))
        #expect(await harness.remote.data == F.finishedWorkout())
        #expect(await harness.remote.pushes.last?.replacing == RemoteVersion("sha_a_mano"))
    }

    @Test("conflicto → Subir local sin conexión: sigue el conflicto")
    func keepLocalOffline() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        #expect(await repository.keepLocal() == .unreachable)
        #expect(await repository.status == SyncStatus(state: .pending, conflict: true))
    }

    @Test("conflicto → Bajar GitHub: lo remoto sustituye a lo local y se acaba el conflicto")
    func keepRemote() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        #expect(await repository.download() == .applied(F.base))
        #expect(await repository.status == SyncStatus(state: .ok, conflict: false))
        #expect(await harness.savedLocally == F.base)
    }

    @Test("bajar de GitHub cancela la subida programada de lo que había antes")
    func downloadCancelsScheduledUpload() async throws {
        let harness = SyncHarness()
        let repository = harness.repositoryWithoutTimer()
        _ = try await repository.start()
        try await repository.update(F.finishedWorkout())
        _ = await repository.download()
        await repository.flush()
        #expect(await harness.remote.pushes.isEmpty)
    }

    @Test("probar conexión no cambia los datos locales")
    func testConnection() async throws {
        let harness = SyncHarness(remote: F.adding(Exercise(id: "sentadilla", name: "Sentadilla")))
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.testConnection(SyncFixtures.location, token: "ghp_test") == .connected)
        #expect(await repository.data == F.base)
        #expect(await harness.savedLocally == F.base)
    }

    @Test("probar conexión distingue el código de error y la falta de red")
    func testConnectionErrors() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        await harness.remote.fail(fetch: .status(401))
        #expect(await repository.testConnection(SyncFixtures.location, token: "malo") == .status(401))
        await harness.remote.fail(fetch: .unreachable)
        #expect(await repository.testConnection(SyncFixtures.location, token: "x") == .unreachable)
        await harness.remote.fail(fetch: .invalidContent)
        #expect(await repository.testConnection(SyncFixtures.location, token: "x") == .invalidContent)
    }

    // MARK: - Configurar GitHub

    @Test("configurar GitHub con la app recién instalada baja los datos, no sube los vacíos")
    func configureFreshInstall() async throws {
        let harness = SyncHarness(local: nil, remote: F.finishedWorkout(), configured: false)
        let repository = harness.repository()
        #expect(try await repository.start() == TrainingData())

        #expect(try await repository.configure(SyncFixtures.location, token: SyncFixtures.token) == .downloaded(F.finishedWorkout()))
        #expect(await harness.remote.pushAttempts == 0)
        #expect(await harness.savedLocally == F.finishedWorkout())
        #expect(await harness.settings.settings.location == SyncFixtures.location)
        #expect(await harness.credentials.token == SyncFixtures.token)
        #expect(await repository.status == SyncStatus(state: .ok, conflict: false))
    }

    @Test("configurar GitHub con datos locales los sube, como la PWA")
    func configureWithData() async throws {
        let harness = SyncHarness(remote: F.base, configured: false)
        let repository = harness.repository()
        _ = try await repository.start()
        try await repository.update(F.finishedWorkout())

        #expect(try await repository.configure(SyncFixtures.location, token: SyncFixtures.token) == .uploading)
        await repository.nextAutoSave()
        #expect(await harness.remote.data == F.finishedWorkout())
        #expect(await repository.status.state == .ok)
    }

    @Test("cambiar de repositorio olvida el sha del anterior")
    func reconfigureForgetsVersion() async throws {
        let harness = SyncHarness(remoteVersion: "sha_viejo")
        let repository = harness.repository()
        _ = try await repository.start()
        _ = await repository.synchronize()
        await harness.remote.replace(with: F.base, version: "sha_otro_repo")
        let other = SyncLocation(repository: "u/otro", branch: "main", path: "db.json")
        _ = try await repository.configure(other, token: SyncFixtures.token)
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        #expect(await harness.remote.pushes.first?.replacing == RemoteVersion("sha_otro_repo"))
    }

    @Test("configurar con la app recién instalada y GitHub caído deja la configuración guardada")
    func configureFreshOffline() async throws {
        let harness = SyncHarness(local: nil, configured: false)
        let repository = harness.repository()
        _ = try await repository.start()
        await harness.remote.fail(fetch: .unreachable)
        #expect(try await repository.configure(SyncFixtures.location, token: SyncFixtures.token) == .downloadFailed)
        #expect(await harness.settings.settings.location == SyncFixtures.location)
        #expect(await harness.remote.pushAttempts == 0)
    }

    // MARK: - Volver a tener red o volver a la app

    @Test("al volver la red con algo pendiente se sube")
    func networkBack() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        await harness.remote.fail()
        #expect(await repository.synchronize() == .uploaded)
    }

    @Test("con un conflicto abierto, volver la red no sube nada")
    func networkBackWithConflict() async throws {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let repository = harness.repository()
        _ = try await repository.start()
        _ = try await repository.saveAndUpload(F.finishedWorkout())
        let attempts = await harness.remote.pushAttempts
        #expect(await repository.synchronize() == .nothing)
        #expect(await harness.remote.pushAttempts == attempts)
    }

    @Test("con un entreno en curso y algo pendiente, sincronizar no sube")
    func synchronizeDuringWorkout() async throws {
        let harness = SyncHarness(local: F.activeWorkout(), pending: true)
        let repository = harness.repository()
        _ = try await repository.start()
        #expect(await repository.synchronize() == .nothing)
        #expect(await harness.remote.pushAttempts == 0)
    }
}

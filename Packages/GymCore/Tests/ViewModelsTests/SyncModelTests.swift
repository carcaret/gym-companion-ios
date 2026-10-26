import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

private typealias F = SyncFixtures

@MainActor
private func models(_ harness: SyncHarness, repository: TrainingRepository? = nil) async -> (AppModel, SyncModel) {
    let repository = repository ?? harness.repository()
    let app = AppModel(repository: repository)
    let sync = SyncModel(repository: repository, app: app)
    await app.start()
    await sync.refresh()
    return (app, sync)
}

// Port por comportamiento de tests/e2e/sync-ui.spec.js: el indicador, los toasts y los botones
// de Ajustes, sin HTML. "data-state" es `status.state`; el toast, `notice`; el modal, las
// propiedades `is…Presented`.
@MainActor
@Suite("Sync — UI y ajustes", .timeLimit(.minutes(1)))
struct SyncUITests {
    @Test("sin GitHub → indicador en estado disabled")
    func disabled() async {
        let (_, sync) = await models(SyncHarness(configured: false))
        #expect(sync.status.state == .disabled)
    }

    @Test("sync ok → indicador muestra estado ok")
    func ok() async throws {
        let harness = SyncHarness()
        let repository = harness.repository()
        let (app, sync) = await models(harness, repository: repository)
        await app.update(F.activeWorkout())
        #expect(await app.finishWorkout(F.finishedWorkout()) == .uploaded)
        await sync.refresh()
        #expect(sync.status.state == .ok)
    }

    // Cambiado con la aprobación del usuario (2026-10-26): el indicador es un menú de iOS que
    // dice el estado, no un botón que lo dice en un aviso.
    @Test("clic en indicador muestra toast con estado")
    func tapIndicator() async {
        let (_, sync) = await models(SyncHarness(configured: false))
        #expect(sync.statusText == SyncText.notConfigured.text)
        #expect(sync.notice == nil)
    }

    @Test("PAT guardado en claro es legible directamente")
    func tokenSaved() async throws {
        let harness = SyncHarness(configured: false)
        let (_, sync) = await models(harness)
        await sync.configure(repository: "user/repo", branch: "", path: "", token: "ghp_cleartext999")
        #expect(await harness.credentials.token == "ghp_cleartext999")
        #expect(await harness.settings.settings.location == SyncLocation(repository: "user/repo", branch: "master", path: "db.json"))
    }

    @Test("Subir a GitHub dispara PUT y muestra toast de éxito")
    func forceUpload() async {
        let harness = SyncHarness()
        let (_, sync) = await models(harness)
        await sync.forceUpload()
        #expect(sync.notice == SyncText.uploaded)
        #expect(await harness.remote.pushes.count == 1)
    }

    @Test("Subir a GitHub sin GitHub configurado → toast warn, no PUT")
    func forceUploadNotConfigured() async {
        let harness = SyncHarness(configured: false)
        let (_, sync) = await models(harness)
        await sync.forceUpload()
        #expect(sync.notice == SyncText.notConfiguredWarning)
        #expect(await harness.remote.pushAttempts == 0)
    }

    @Test("Subir a GitHub con conflicto activo → abre modal de conflicto")
    func forceUploadConflict() async {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let (app, sync) = await models(harness)
        #expect(await app.finishWorkout(F.finishedWorkout()) == .conflict)
        await sync.refresh()
        #expect(sync.status == SyncStatus(state: .pending, conflict: true))
        await sync.forceUpload()
        #expect(sync.isConflictPresented)
    }

    @Test("probar conexión NO sobrescribe la DB local")
    func testConnection() async {
        let harness = SyncHarness(remote: TrainingData(catalog: Catalog([Exercise(id: "sentadilla", name: "Sentadilla")])))
        let (app, sync) = await models(harness)
        await sync.testConnection(repository: "u/r", branch: "main", path: "db.json", token: "ghp_test")
        #expect(sync.notice == SyncText.connected)
        #expect(app.data == F.base)
        #expect(await harness.savedLocally == F.base)
    }
}

// La parte de interfaz de los e2e de github-sync.spec.js y sync-canonicos.spec.js.
@MainActor
@Suite("Sincronización en la interfaz", .timeLimit(.minutes(1)))
struct SyncModelTests {
    @Test("GitHub devuelve 401 → muestra mensaje de error")
    func unauthorized() async {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .status(401))
        let (_, sync) = await models(harness)
        await sync.download()
        #expect(sync.notice?.text.contains("No se pudo") == true)
    }

    @Test("Canónico B: botón \"Sincronizar desde GitHub\" sobreescribe local con remote tras confirmación")
    func download() async {
        let remote = F.adding(Exercise(id: "dominadas", name: "Dominadas"))
        let (app, sync) = await models(SyncHarness(remote: remote))
        await sync.download()
        #expect(sync.notice == SyncText.downloaded)
        #expect(app.data == remote)
    }

    @Test("Canónico D: 409 en PUT → indicador pendiente → modal con 3 opciones")
    func conflictPrompt() async {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let (app, sync) = await models(harness)
        _ = await app.finishWorkout(F.finishedWorkout())
        await sync.refresh()
        #expect(sync.status.state == .pending)

        // El menú del indicador ofrece resolverlo (antes se abría al tocar el indicador).
        #expect(sync.menuAction == .resolveConflict)
        sync.resolveConflict()
        #expect(sync.isConflictPresented)
        // Cancelar no hace nada.
        sync.cancelConflict()
        #expect(!sync.isConflictPresented)
        #expect(sync.status == SyncStatus(state: .pending, conflict: true))
    }

    @Test("Canónico G: arranque needsUpload=false + remote≠local → local sobreescrito + toast")
    func remoteApplied() async {
        let remote = F.adding(Exercise(id: "dominadas", name: "Dominadas"))
        let (app, sync) = await models(SyncHarness(remote: remote))
        await sync.synchronize()
        #expect(app.data == remote)
        #expect(sync.notice == SyncText.remoteApplied)
    }

    @Test("Canónico F: arranque needsUpload=false + remote==local → GET ocurre, sin toast, sin PUT, local intacto")
    func nothingToDo() async {
        let (_, sync) = await models(SyncHarness())
        await sync.synchronize()
        #expect(sync.notice == nil)
    }

    @Test("Canónico K: GitHub inaccesible al arrancar → local intacto, sin toast de error")
    func offlineQuiet() async {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .unreachable)
        let (_, sync) = await models(harness)
        await sync.synchronize()
        #expect(sync.notice == nil)
    }

    @Test("con algo pendiente, el menú del indicador dice que falta subir y ofrece sincronizar")
    func pendingMenu() async {
        let (_, sync) = await models(SyncHarness(pending: true))
        #expect(sync.statusText == SyncText.pendingChanges.text)
        #expect(sync.menuAction == .syncNow)
    }

    @Test("todo subido, el menú del indicador dice que está sincronizado y ofrece sincronizar")
    func syncedMenu() async {
        let (_, sync) = await models(SyncHarness())
        #expect(sync.statusText == SyncText.synced.text)
        #expect(sync.menuAction == .syncNow)
    }

    @Test("sin GitHub, el menú del indicador ofrece configurarlo")
    func disabledMenu() async {
        let (_, sync) = await models(SyncHarness(configured: false))
        #expect(sync.menuAction == .configure)
    }

    @Test("con un conflicto, el menú del indicador lo dice")
    func conflictMenu() async {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let (app, sync) = await models(harness)
        _ = await app.finishWorkout(F.finishedWorkout())
        await sync.refresh()
        #expect(sync.statusText == SyncText.conflictTitle)
        #expect(sync.menuAction == .resolveConflict)
    }

    @Test("al volver la red, lo pendiente se sube y se avisa")
    func reconnect() async {
        let harness = SyncHarness(pending: true)
        let (_, sync) = await models(harness)
        await sync.synchronize(afterReconnect: true)
        #expect(sync.notice == SyncText.savedAfterReconnect)
        #expect(sync.status.state == .ok)
    }

    @Test("conflicto → Subir local: se resuelve y se cierra")
    func keepLocal() async {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let (app, sync) = await models(harness)
        _ = await app.finishWorkout(F.finishedWorkout())
        await harness.remote.fail()
        await sync.refresh()
        sync.resolveConflict()
        await sync.keepLocal()
        #expect(sync.notice == SyncText.keptLocal)
        #expect(!sync.isConflictPresented)
        #expect(sync.status == SyncStatus(state: .ok, conflict: false))
    }

    @Test("conflicto → Subir local sin red: avisa y el conflicto sigue abierto")
    func keepLocalOffline() async {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let (app, sync) = await models(harness)
        _ = await app.finishWorkout(F.finishedWorkout())
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        await sync.refresh()
        sync.resolveConflict()
        await sync.keepLocal()
        #expect(sync.notice == SyncText.cannotConnect)
        #expect(sync.isConflictPresented)
    }

    @Test("conflicto → Bajar GitHub: lo remoto se ve al momento")
    func keepRemote() async {
        let harness = SyncHarness()
        await harness.remote.fail(push: .conflict)
        let (app, sync) = await models(harness)
        _ = await app.finishWorkout(F.finishedWorkout())
        await sync.refresh()
        sync.resolveConflict()
        #expect(sync.isConflictPresented)
        await sync.keepRemote()
        #expect(sync.notice == SyncText.keptRemote)
        #expect(app.data == F.base)
        #expect(!sync.isConflictPresented)
    }

    // Antes avisaba con «Guardado» tras cada cambio, como la PWA (quitado con la aprobación del
    // usuario, 2026-10-26).
    @Test("una subida diferida que sale bien no avisa: lo dice el indicador")
    func autoSaved() async {
        let harness = SyncHarness()
        let repository = harness.repository()
        let (app, sync) = await models(harness, repository: repository)
        let observing = Task { await sync.observe() }
        await app.update(F.finishedWorkout())
        while await harness.remote.pushes.isEmpty { await Task.yield() }
        // Lo que llegue tras la subida (el estado y el fin de la subida) ya se ha atendido.
        for _ in 0..<100 { await Task.yield() }
        #expect(sync.status.state == .ok)
        #expect(sync.notice == nil)
        observing.cancel()
    }

    @Test("configurar sin repo o sin token no guarda nada")
    func configureRequiresFields() async {
        let harness = SyncHarness(configured: false)
        let (_, sync) = await models(harness)
        await sync.configure(repository: "  ", branch: "main", path: "db.json", token: "ghp")
        #expect(sync.notice == SyncText.repoAndTokenRequired)
        await sync.configure(repository: "u/r", branch: "main", path: "db.json", token: " ")
        #expect(sync.notice == SyncText.repoAndTokenRequired)
        #expect(await harness.credentials.token == nil)
    }

    @Test("configurar con la app vacía baja los datos y se ven al momento")
    func configureDownloads() async {
        let harness = SyncHarness(local: nil, remote: F.finishedWorkout(), configured: false)
        let (app, sync) = await models(harness)
        await sync.configure(repository: " u/r ", branch: "main", path: "db.json", token: " ghp_x ")
        #expect(app.data == F.finishedWorkout())
        #expect(sync.notice == SyncText.downloaded)
        #expect(await harness.credentials.token == "ghp_x")
    }

    @Test("probar conexión: el código de error y la falta de red")
    func testConnectionErrors() async {
        let harness = SyncHarness()
        let (_, sync) = await models(harness)
        await harness.remote.fail(fetch: .status(404))
        await sync.testConnection(repository: "u/r", branch: "main", path: "db.json", token: "t")
        #expect(sync.notice == SyncText.connectionError(status: 404))
        await harness.remote.fail(fetch: .unreachable)
        await sync.testConnection(repository: "u/r", branch: "main", path: "db.json", token: "t")
        #expect(sync.notice == SyncText.cannotConnectAtAll)
    }

    @Test("terminar un entreno sin poder subirlo avisa de que queda guardado en el iPhone")
    func savedLocallyPrompt() async {
        let harness = SyncHarness()
        await harness.remote.fail(fetch: .unreachable, push: .unreachable)
        let (app, sync) = await models(harness)
        let result = await app.finishWorkout(F.finishedWorkout())
        sync.workoutFinished(result)
        #expect(sync.isSavedLocallyPresented)
        sync.workoutFinished(.uploaded)
        sync.isSavedLocallyPresented = false
        sync.workoutFinished(.notConfigured)
        #expect(!sync.isSavedLocallyPresented)
    }
}

// Tirar hacia abajo en Historial (`refreshable`): sincroniza al momento y siempre dice cómo ha
// quedado, porque lo ha pedido el usuario.
@MainActor
@Suite("Sync — tirar para sincronizar", .timeLimit(.minutes(1)))
struct SyncPullToRefreshTests {
    @Test("sin GitHub avisa de que no está configurado")
    func notConfigured() async {
        let (_, sync) = await models(SyncHarness(configured: false))
        await sync.pullToRefresh()
        #expect(sync.notice == SyncText.notConfigured)
    }

    @Test("con lo remoto distinto, lo aplica y lo dice")
    func remoteApplied() async {
        let remote = F.adding(Exercise(id: "dominadas", name: "Dominadas"))
        let (app, sync) = await models(SyncHarness(remote: remote))
        await sync.pullToRefresh()
        #expect(app.data == remote)
        #expect(sync.notice == SyncText.remoteApplied)
    }

    @Test("con todo igual dice que está sincronizado")
    func synced() async {
        let (_, sync) = await models(SyncHarness())
        await sync.pullToRefresh()
        #expect(sync.notice == SyncText.synced)
    }

    @Test("con algo pendiente lo sube y dice que está sincronizado")
    func uploadsPending() async {
        let (_, sync) = await models(SyncHarness(pending: true))
        await sync.pullToRefresh()
        #expect(sync.status.state == .ok)
        #expect(sync.notice == SyncText.synced)
    }

    @Test("sin red dice que hay cambios pendientes")
    func offline() async {
        let harness = SyncHarness(pending: true)
        await harness.remote.fail(fetch: .unreachable)
        let (_, sync) = await models(harness)
        await sync.pullToRefresh()
        #expect(sync.notice == SyncText.pendingChanges)
    }
}

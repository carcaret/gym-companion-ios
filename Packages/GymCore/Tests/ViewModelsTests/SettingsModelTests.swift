import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

@MainActor
private struct SettingsHarness {
    let harness: SyncHarness
    let app: AppModel
    let sync: SyncModel
    let model: SettingsModel

    static func make(configured: Bool = false, remote: TrainingData? = SyncFixtures.base) async -> SettingsHarness {
        let base = await AppHarness.start(SyncHarness(local: PWATestDB.data, remote: remote, configured: configured))
        let model = SettingsModel(sync: base.sync, repository: base.repository, version: AppVersion(marketing: "0.1", build: "15"))
        await model.load()
        return SettingsHarness(harness: base.harness, app: base.app, sync: base.sync, model: model)
    }
}

// tests/e2e/settings.spec.js
@MainActor
@Suite("Ajustes — GitHub y PAT en claro")
struct SettingsTests {
    @Test("guardar configuración GitHub almacena PAT en texto plano")
    func savesToken() async {
        let settings = await SettingsHarness.make()
        settings.model.repository = "user/repo"
        settings.model.branch = "main"
        settings.model.token = "ghp_plaintext123"
        settings.model.path = "db.json"
        await settings.model.save()
        // En el iPhone va al Llavero, no a un fichero; lo que se guarda es el token tal cual.
        #expect(await settings.harness.credentials.token == "ghp_plaintext123")
    }

    // Cambiado con la aprobación del usuario (2026-10-27, auditoría de los avisos): en vez de
    // avisar al tocarlo, «Guardar» está desactivado, como en los formularios de iOS.
    @Test("guardar configuración GitHub sin PAT muestra error")
    func noToken() async {
        let settings = await SettingsHarness.make()
        settings.model.repository = "user/repo"
        #expect(!settings.model.canSave)
        settings.model.token = "  "
        #expect(!settings.model.canSave)
        settings.model.token = "ghp"
        #expect(settings.model.canSave)
    }

    // Cambiado con la aprobación del usuario (2026-10-27), como el anterior.
    @Test("guardar sin repo muestra error")
    func noRepository() async {
        let settings = await SettingsHarness.make()
        settings.model.token = "ghp_token"
        #expect(!settings.model.canSave)
    }

    @Test("al abrir ajustes con PAT guardado, se muestra en el campo")
    func showsToken() async {
        let settings = await SettingsHarness.make(configured: true)
        #expect(settings.model.token == SyncFixtures.token)
        #expect(settings.model.repository == "u/r")
        #expect(settings.model.branch == "main")
        #expect(settings.model.path == "db.json")
    }

    // Cambiado con la aprobación del usuario (2026-10-27): «Guardar» prueba la conexión antes de
    // guardar, y probarla no toca los datos (con datos en el iPhone, se suben).
    @Test("probar conexión NO modifica la DB")
    func testDoesNotModify() async {
        let settings = await SettingsHarness.make(configured: true, remote: TrainingData(catalog: Catalog([Exercise(id: "sentadilla", name: "Sentadilla")])))
        settings.model.branch = "otra"
        await settings.model.save()
        #expect(settings.model.connectionResult == nil)
        #expect(settings.app.data == PWATestDB.data)
        #expect(await settings.harness.savedLocally == PWATestDB.data)
    }
}

// Cambiados con la aprobación del usuario (2026-10-27): no hay botón «Probar conexión»; «Guardar»
// prueba lo escrito y, si va bien, guarda y cierra la hoja, como al añadir una cuenta de correo. Si
// falla, el error sale debajo de los campos y no se guarda nada.
@MainActor
@Suite("probar conexión — respuestas de red")
struct SettingsConnectionTests {
    @Test("probar conexión sin config guardada → toast de aviso")
    func notSaved() async {
        let settings = await SettingsHarness.make()
        #expect(!settings.model.canSave)
        settings.model.repository = "u/r"
        settings.model.token = "ghp_sin_guardar"
        #expect(settings.model.canSave)
        settings.sync.showSettings()
        await settings.model.save()
        #expect(await settings.harness.credentials.token == "ghp_sin_guardar")
        #expect(!settings.sync.isSettingsPresented, "Bien guardado, la hoja se cierra")
    }

    @Test("probar conexión con respuesta 200 → toast de éxito")
    func ok() async {
        let settings = await SettingsHarness.make(configured: true)
        settings.sync.showSettings()
        settings.model.branch = "main2"
        await settings.model.save()
        #expect(settings.model.connectionResult == nil)
        #expect(!settings.sync.isSettingsPresented)
        #expect(await settings.harness.settings.settings.location?.branch == "main2")
    }

    @Test("probar conexión con 401 → toast de error con código")
    func unauthorized() async {
        let settings = await SettingsHarness.make(configured: true)
        settings.sync.showSettings()
        await settings.harness.remote.fail(fetch: .status(401))
        settings.model.token = "ghp_otro"
        await settings.model.save()
        // Cambiado con la aprobación del usuario (repaso de la HIG F2, 2026-10-28): el error ya no
        // lleva el código («Error 401 — …»), sino qué pasa y qué revisar. En la PWA, contiene "401".
        #expect(settings.model.connectionResult == SyncText.connectionError(status: 401))
        #expect(settings.model.connectionResult?.text.contains("token") == true)
        #expect(settings.model.connectionResult?.kind == .error)
        #expect(settings.sync.isSettingsPresented, "Con error, la hoja sigue abierta")
        #expect(await settings.harness.credentials.token == SyncFixtures.token, "No se guarda nada")
    }

    @Test("probar conexión con fallo de red → toast de error genérico")
    func offline() async {
        let settings = await SettingsHarness.make(configured: true)
        await settings.harness.remote.fail(fetch: .unreachable)
        settings.model.token = "ghp_otro"
        await settings.model.save()
        #expect(settings.model.connectionResult == SyncText.offline)
        #expect(await settings.harness.credentials.token == SyncFixtures.token)
    }

    @Test("al cambiar un campo, el resultado de la prueba anterior se va")
    func resultClears() async {
        let settings = await SettingsHarness.make(configured: true)
        await settings.harness.remote.fail(fetch: .unreachable)
        settings.model.token = "ghp_otro"
        await settings.model.save()
        #expect(settings.model.connectionResult != nil)
        settings.model.branch = "otra"
        #expect(settings.model.connectionResult == nil)
    }

    @Test("mientras guarda, la barra lo dice y los botones esperan")
    func activity() async {
        let settings = await SettingsHarness.make(configured: true)
        settings.model.branch = "otra"
        await settings.harness.remote.holdFetches()
        let saving = Task { await settings.model.save() }
        await settings.harness.remote.waitForHeldFetch()
        #expect(settings.model.activity == .saving)
        #expect(!settings.model.canSave)
        #expect(!settings.model.canDownload)
        await settings.harness.remote.releaseFetches()
        await saving.value
        #expect(settings.model.activity == nil)
        #expect(settings.model.canDownload)
    }
}

// Propio de la app (2026-10-27): cerrar la hoja con algo escrito sin guardar pregunta antes.
@MainActor
@Suite("Ajustes — cerrar")
struct SettingsCloseTests {
    @Test("sin cambios, la X cierra al momento")
    func closeClean() async {
        let settings = await SettingsHarness.make(configured: true)
        settings.sync.showSettings()
        settings.model.requestClose()
        #expect(!settings.sync.isSettingsPresented)
        #expect(!settings.model.isDiscardPromptPresented)
    }

    @Test("con cambios, la X pregunta; descartar cierra y seguir deja lo escrito")
    func closeDirty() async {
        let settings = await SettingsHarness.make(configured: true)
        settings.sync.showSettings()
        settings.model.repository = "otro/repo"
        settings.model.requestClose()
        #expect(settings.model.isDiscardPromptPresented)
        #expect(settings.sync.isSettingsPresented)
        settings.model.keepEditing()
        #expect(settings.model.repository == "otro/repo")
        settings.model.requestClose()
        settings.model.keepEditing()
        settings.model.discardChanges()
        #expect(!settings.sync.isSettingsPresented)
    }

    @Test("sin cambios, Guardar no se ofrece")
    func saveNeedsChanges() async {
        let settings = await SettingsHarness.make(configured: true)
        #expect(!settings.model.canSave)
        settings.model.path = "otro.json"
        #expect(settings.model.canSave)
    }
}

// tests/e2e/login.spec.js
@MainActor
@Suite("Arranque directo (sin login)")
struct DirectStartTests {
    @Test("la app arranca directamente sin pantalla de login")
    func noLogin() async {
        let settings = await SettingsHarness.make()
        #expect(settings.app.data == PWATestDB.data)
        #expect(settings.app.loadError == nil)
    }

    @Test("sin datos locales → arranca con datos por defecto (db.json)")
    func noData() async {
        let app = AppModel(repository: SyncHarness(local: nil, configured: false).repository())
        await app.start()
        #expect(app.data == TrainingData())
    }

    @Test("la vista inicial es Rutinas")
    func startsOnRoutines() async {
        let settings = await SettingsHarness.make()
        let today = TodayModel(app: settings.app, clock: FixedClock(SyncFixtures.today))
        #expect(NavigationModel().selectedTab == .routines)
        #expect(today.title == "Rutinas")
    }

    // Que el botón está en la barra lo comprueba `ScreenshotTests` (identificador "sync-indicator").
    // Cambiado con la aprobación del usuario (2026-10-26): el indicador es un menú que dice el
    // estado, no un aviso.
    @Test("el indicador de sync es visible en el header")
    func indicator() async {
        let settings = await SettingsHarness.make()
        #expect(settings.sync.statusText == SyncText.notConfigured.text)
        #expect(settings.model.statusText == settings.sync.statusText)
    }

    @Test("sin GitHub configurado → indicador en estado disabled")
    func disabled() async {
        #expect(await SettingsHarness.make().sync.status.state == .disabled)
    }
}

@MainActor
@Suite("Ajustes")
struct SettingsModelTests {
    @Test("enseña la versión y la compilación de la app")
    func version() async {
        #expect(await SettingsHarness.make().model.versionLabel == "Versión 0.1 (15)")
    }

    @Test("guardar con rama y ruta vacías usa master y db.json, y los campos lo reflejan")
    func defaults() async {
        let settings = await SettingsHarness.make()
        settings.model.repository = "u/r"
        settings.model.token = "ghp"
        await settings.model.save()
        #expect(settings.model.branch == "master")
        #expect(settings.model.path == "db.json")
    }

    @Test("descargar pide confirmación y, confirmado, sustituye lo local")
    func download() async {
        let settings = await SettingsHarness.make(configured: true)
        settings.model.requestDownload()
        #expect(settings.model.isDownloadConfirmationPresented)
        await settings.model.confirmDownload()
        #expect(!settings.model.isDownloadConfirmationPresented)
        #expect(settings.app.data == SyncFixtures.base)
        #expect(settings.app.notice == SyncText.remoteApplied)
    }
}

// Propio de la app: los ajustes van en una hoja, y deslizarla hacia abajo no se lleva lo escrito.
@MainActor
@Suite("Ajustes — cambios sin guardar")
struct SettingsUnsavedTests {
    @Test("al abrir, con o sin GitHub, no hay nada sin guardar")
    func cleanOnOpen() async {
        #expect(!(await SettingsHarness.make().model.hasUnsavedChanges))
        #expect(!(await SettingsHarness.make(configured: true).model.hasUnsavedChanges))
    }

    @Test("cambiar cualquier campo deja cambios sin guardar, y deshacerlo los quita")
    func editing() async {
        let settings = await SettingsHarness.make(configured: true)
        for field in [\SettingsModel.repository, \.branch, \.path, \.token] {
            let saved = settings.model[keyPath: field]
            settings.model[keyPath: field] = saved + "x"
            #expect(settings.model.hasUnsavedChanges)
            settings.model[keyPath: field] = saved
            #expect(!settings.model.hasUnsavedChanges)
        }
    }

    @Test("guardar deja la hoja sin cambios pendientes")
    func saveClears() async {
        let settings = await SettingsHarness.make()
        settings.model.repository = "user/repo"
        settings.model.token = "ghp_x"
        #expect(settings.model.hasUnsavedChanges)
        await settings.model.save()
        #expect(!settings.model.hasUnsavedChanges)
    }

    @Test("volver a abrir la hoja descarta lo escrito sin guardar")
    func reopenDiscards() async {
        let settings = await SettingsHarness.make(configured: true)
        settings.model.repository = "otro/repo"
        await settings.model.load()
        #expect(settings.model.repository == "u/r")
        #expect(!settings.model.hasUnsavedChanges)
    }
}

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
        let harness = SyncHarness(local: PWATestDB.data, remote: remote, configured: configured)
        let repository = harness.repository()
        let app = AppModel(repository: repository)
        let sync = SyncModel(repository: repository, app: app)
        await app.start()
        await sync.refresh()
        let model = SettingsModel(sync: sync, repository: repository, version: AppVersion(marketing: "0.1", build: "15"))
        await model.load()
        return SettingsHarness(harness: harness, app: app, sync: sync, model: model)
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

    @Test("guardar configuración GitHub sin PAT muestra error")
    func noToken() async {
        let settings = await SettingsHarness.make()
        settings.model.repository = "user/repo"
        await settings.model.save()
        #expect(settings.app.notice?.text.contains("requeridos") == true)
    }

    @Test("guardar sin repo muestra error")
    func noRepository() async {
        let settings = await SettingsHarness.make()
        settings.model.token = "ghp_token"
        await settings.model.save()
        #expect(settings.app.notice?.text.contains("requeridos") == true)
    }

    @Test("al abrir ajustes con PAT guardado, se muestra en el campo")
    func showsToken() async {
        let settings = await SettingsHarness.make(configured: true)
        #expect(settings.model.token == SyncFixtures.token)
        #expect(settings.model.repository == "u/r")
        #expect(settings.model.branch == "main")
        #expect(settings.model.path == "db.json")
    }

    @Test("probar conexión NO modifica la DB")
    func testDoesNotModify() async {
        let settings = await SettingsHarness.make(configured: true, remote: TrainingData(catalog: Catalog([Exercise(id: "sentadilla", name: "Sentadilla")])))
        await settings.model.testConnection()
        #expect(settings.app.notice != nil)
        #expect(settings.app.data == PWATestDB.data)
        #expect(await settings.harness.savedLocally == PWATestDB.data)
    }
}

@MainActor
@Suite("probar conexión — respuestas de red")
struct SettingsConnectionTests {
    @Test("probar conexión sin config guardada → toast de aviso")
    func notSaved() async {
        let settings = await SettingsHarness.make()
        await settings.model.testConnection()
        #expect(settings.app.notice?.text == "Guarda la configuración primero")
    }

    @Test("probar conexión con respuesta 200 → toast de éxito")
    func ok() async {
        let settings = await SettingsHarness.make(configured: true)
        await settings.model.testConnection()
        #expect(settings.app.notice?.text == "Conexión exitosa")
    }

    @Test("probar conexión con 401 → toast de error con código")
    func unauthorized() async {
        let settings = await SettingsHarness.make(configured: true)
        await settings.harness.remote.fail(fetch: .status(401))
        await settings.model.testConnection()
        #expect(settings.app.notice?.text.contains("401") == true)
    }

    @Test("probar conexión con fallo de red → toast de error genérico")
    func offline() async {
        let settings = await SettingsHarness.make(configured: true)
        await settings.harness.remote.fail(fetch: .unreachable)
        await settings.model.testConnection()
        #expect(settings.app.notice?.text.contains("No se pudo conectar") == true)
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
        let today = TodayModel(app: settings.app, sync: settings.sync, clock: FixedClock(SyncFixtures.today))
        #expect(NavigationModel().selectedTab == .routines)
        #expect(today.title == "Rutinas")
    }

    // Que el botón está en la barra lo comprueba `ScreenshotTests` (identificador "sync-indicator").
    @Test("el indicador de sync es visible en el header")
    func indicator() async {
        let settings = await SettingsHarness.make()
        settings.sync.tapIndicator()
        #expect(settings.app.notice != nil)
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
        #expect(settings.app.notice == SyncText.downloaded)
    }

    @Test("subir a GitHub sube lo local")
    func upload() async {
        let settings = await SettingsHarness.make(configured: true)
        await settings.model.upload()
        #expect(settings.app.notice == SyncText.uploaded)
        #expect(await settings.harness.remote.data == PWATestDB.data)
    }
}

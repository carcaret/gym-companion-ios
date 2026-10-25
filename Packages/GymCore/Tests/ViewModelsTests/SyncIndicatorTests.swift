import Application
import Domain
import GymCoreTesting
import Testing
import ViewModels

// Portados por comportamiento de tests/e2e/sync-ui.spec.js de la PWA: lo que allí era el botón
// del indicador y los botones de Ajustes es aquí el estado de AppModel.

private let today = LocalDate(year: 2026, month: 10, day: 25)!
private let base = TrainingData(catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca")]))

@MainActor
private func model(configured: Bool = true, remote: FakeRemoteTrainingData = FakeRemoteTrainingData(base), local: TrainingData = base)
    -> (AppModel, FakeRemoteTrainingData, InMemoryTrainingDataStore.Storage)
{
    let storage = InMemoryTrainingDataStore.Storage(local)
    let store = InMemoryTrainingDataStore(storage: storage)
    let sync = Synchronizer(store: store, metadataStore: InMemorySyncMetadataStore(), remote: configured ? remote : nil,
                            clock: FixedClock(today), sleep: { _ in })
    return (AppModel(startUp: StartUp(store: store), synchronizer: sync), remote, storage)
}

@MainActor
@Suite("Sync — UI y ajustes")
struct SyncIndicatorTests {
    @Test("sin GitHub → indicador en estado disabled")
    func disabled() async {
        let (app, _, _) = model(configured: false)
        await app.start()
        #expect(app.syncStatus == .disabled)
    }

    @Test("sync ok → indicador muestra estado ok")
    func ok() async {
        let (app, _, _) = model()
        await app.start()
        #expect(app.syncStatus == .ok)
    }

    @Test("clic en indicador muestra toast con estado")
    func tap() async {
        let (app, _, _) = model()
        await app.start()
        app.tapSyncIndicator()
        #expect(app.notice == "Sincronizado con GitHub")
        #expect(!app.showsConflict)
    }

    @Test("Subir a GitHub dispara PUT y muestra toast de éxito")
    func upload() async {
        let (app, remote, _) = model()
        await app.start()
        await app.uploadToGitHub()
        #expect(await remote.pushes.count == 1)
        #expect(app.notice == "Subido a GitHub")
    }

    @Test("Subir a GitHub sin GitHub configurado → toast warn, no PUT")
    func uploadNotConfigured() async {
        let (app, remote, _) = model(configured: false)
        await app.start()
        await app.uploadToGitHub()
        #expect(app.notice == "GitHub no configurado")
        #expect(await remote.pushes.isEmpty)
    }

    @Test("Subir a GitHub con conflicto activo → abre modal de conflicto")
    func uploadWithConflict() async throws {
        let (app, remote, _) = model()
        await app.start()
        await remote.set(TrainingData(), revision: "sha_editado_a_mano")
        await app.uploadToGitHub()
        #expect(app.syncStatus == .conflict)
        #expect(app.showsConflict)
        app.resolveConflict(.cancel)
        #expect(!app.showsConflict)
        await app.uploadToGitHub()
        #expect(app.showsConflict)
    }

    @Test("con conflicto, tocar el indicador ofrece las tres opciones; cada una hace lo suyo")
    func conflictChoices() async throws {
        let (app, remote, storage) = model()
        await app.start()
        let theirs = TrainingData(catalog: Catalog([Exercise(id: "remo", name: "Remo")]))
        await remote.set(theirs, revision: "sha_editado_a_mano")
        await app.uploadToGitHub()
        app.resolveConflict(.cancel)
        app.tapSyncIndicator()
        #expect(app.showsConflict)
        await app.resolveConflictAndWait(.takeRemote)
        #expect(app.data == theirs)
        #expect(try await InMemoryTrainingDataStore(storage: storage).load() == theirs)
        #expect(app.syncStatus == .ok)
        #expect(app.notice == "Datos descargados de GitHub")
    }

    @Test("al arrancar con datos más nuevos en GitHub, la app los muestra y avisa")
    func remoteApplied() async {
        let theirs = TrainingData(catalog: Catalog([Exercise(id: "remo", name: "Remo")]))
        let (app, _, _) = model(remote: FakeRemoteTrainingData(theirs))
        await app.start()
        await app.waitForEvents()
        #expect(app.data == theirs)
        #expect(app.notice == "Datos actualizados desde GitHub")
    }
}

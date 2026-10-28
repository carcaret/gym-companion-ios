import Application
import Domain
import GymCoreTesting
import Testing
import ViewModels

@MainActor
@Suite("Estado de la app")
struct AppModelTests {
    @Test("al arrancar carga los datos")
    func loads() async {
        let harness = SyncHarness(local: TrainingDataStoreContract.sample, configured: false)
        let model = AppModel(repository: harness.repository())
        #expect(model.data == nil)
        await model.start()
        #expect(model.data == TrainingDataStoreContract.sample)
        #expect(model.loadError == nil)
    }

    @Test("si no puede leer los datos, se queda sin datos y con el error")
    func failure() async {
        let repository = TrainingRepository(
            store: FailingStore(), settings: InMemorySyncSettingsStore(), credentials: InMemoryCredentialStore(),
            remote: InMemoryRemote(storage: .init()), clock: FixedClock(SyncFixtures.today), background: RecordingBackgroundActivity()
        )
        let model = AppModel(repository: repository)
        await model.start()
        #expect(model.data == nil)
        #expect(model.loadError != nil)
    }

    @Test("arrancar dos veces no vuelve a cargar")
    func once() async {
        let harness = SyncHarness(local: nil, configured: false)
        let model = AppModel(repository: harness.repository())
        await model.start()
        await model.start()
        #expect(await harness.local.saves == 1)
    }

    @Test("un cambio se ve al momento y se guarda")
    func update() async {
        let harness = SyncHarness(configured: false)
        let model = AppModel(repository: harness.repository())
        await model.start()
        await model.update(SyncFixtures.finishedWorkout())
        #expect(model.data == SyncFixtures.finishedWorkout())
        #expect(await harness.savedLocally == SyncFixtures.finishedWorkout())
    }
}

// Propio de la app (2026-10-27): los errores de los datos se ven. Antes se guardaban en el modelo
// y ninguna pantalla los enseñaba: la app salía vacía, como si no hubiera nada.
@MainActor
@Suite("Errores de los datos")
struct AppModelDataErrorTests {
    @Test("si un cambio no se puede guardar, avisa una vez hasta que vuelva a guardarse")
    func saveFailure() async {
        let harness = SyncHarness(configured: false)
        let model = AppModel(repository: harness.repository())
        await model.start()
        await harness.local.fail(saving: true)
        await model.update(SyncFixtures.finishedWorkout())
        #expect(model.data == SyncFixtures.finishedWorkout())
        #expect(model.isSaveErrorPresented)
        model.isSaveErrorPresented = false
        await model.update(SyncFixtures.activeWorkout())
        #expect(!model.isSaveErrorPresented, "Mientras sigue sin poder guardar, no avisa en cada cambio")
        await harness.local.fail()
        await model.update(SyncFixtures.finishedWorkout())
        #expect(model.saveError == nil)
        await harness.local.fail(saving: true)
        _ = await model.finishWorkout(SyncFixtures.finishedWorkout())
        #expect(model.isSaveErrorPresented, "Tras guardar bien, el siguiente fallo vuelve a avisar")
    }

    /// La alerta ofrece reintentar, no solo «Entendido» (repaso de la HIG, 2026-10-28).
    @Test("si un cambio no se pudo guardar, «Reintentar» lo vuelve a guardar y, si falla, vuelve a avisar")
    func retrySave() async {
        let harness = SyncHarness(configured: false)
        let model = AppModel(repository: harness.repository())
        await model.start()
        await harness.local.fail(saving: true)
        await model.update(SyncFixtures.finishedWorkout())
        model.isSaveErrorPresented = false

        await model.retrySave()
        #expect(model.saveError != nil)
        #expect(model.isSaveErrorPresented, "Lo pidió el usuario: si sigue fallando, se lo dice")

        model.isSaveErrorPresented = false
        await harness.local.fail()
        await model.retrySave()
        #expect(model.saveError == nil)
        #expect(!model.isSaveErrorPresented)
        #expect(await harness.local.data == SyncFixtures.finishedWorkout())
    }

    @Test("si no puede leer los datos, se puede reintentar")
    func retry() async {
        let harness = SyncHarness(configured: false)
        await harness.local.fail(loading: true)
        let model = AppModel(repository: harness.repository())
        await model.start()
        #expect(model.loadError != nil)
        await harness.local.fail()
        await model.start()
        #expect(model.data == SyncFixtures.base)
        #expect(model.loadError == nil)
    }

    @Test("si no puede leer los datos, descargarlos de GitHub los recupera")
    func recoverFromGitHub() async {
        let remote = SyncFixtures.finishedWorkout()
        let harness = SyncHarness(remote: remote)
        await harness.local.fail(loading: true)
        let repository = harness.repository()
        let model = AppModel(repository: repository)
        let sync = SyncModel(repository: repository, app: model)
        await model.start()
        await sync.refresh()
        #expect(model.loadError != nil)
        #expect(sync.status.state != .disabled, "Con GitHub, la pantalla del error ofrece descargar")
        await sync.download()
        #expect(model.data == remote)
        #expect(model.loadError == nil)
        #expect(await harness.local.data == remote)
    }
}

private struct FailingStore: TrainingDataStore {
    struct Failure: Error {}
    func load() async throws -> TrainingData? { throw Failure() }
    func save(_ data: TrainingData) async throws {}
}

@MainActor
@Suite("Estado de la app y el reloj")
struct AppModelWatchTests {
    @Test("al arrancar, el reloj recibe el entreno en curso")
    func startSends() async {
        let publisher = RecordingWatchPublisher()
        let harness = SyncHarness(local: SyncFixtures.activeWorkout(), configured: false)
        let model = AppModel(repository: harness.repository(), watch: WatchRelay(publisher: publisher, clock: FixedClock(SyncFixtures.today)))
        await model.start()
        #expect(publisher.published == [SyncFixtures.activeWorkout().watchSnapshot(today: SyncFixtures.today)])
    }

    @Test("cada cambio del entreno llega al reloj")
    func changesSend() async {
        let publisher = RecordingWatchPublisher()
        let harness = SyncHarness(local: SyncFixtures.activeWorkout(), configured: false)
        let model = AppModel(repository: harness.repository(), watch: WatchRelay(publisher: publisher, clock: FixedClock(SyncFixtures.today)))
        await model.start()
        await model.update(SyncFixtures.activeWorkout(weight: 62.5))
        _ = await model.finishWorkout(SyncFixtures.finishedWorkout())
        #expect(publisher.published.map { $0.workout?.exercises.first?.weight } == [60, 62.5, nil])
    }

    @Test("al volver a la app, el reloj se pone al día (otro día, otro entreno)")
    func refresh() async {
        let publisher = RecordingWatchPublisher()
        let clock = SettableClock(SyncFixtures.today)
        let harness = SyncHarness(local: SyncFixtures.activeWorkout(), configured: false)
        let model = AppModel(repository: harness.repository(), watch: WatchRelay(publisher: publisher, clock: clock))
        await model.start()
        clock.day = SyncFixtures.today.adding(days: 1)
        model.refreshWatch()
        #expect(publisher.published.map { $0.workout == nil } == [false, true])
    }
}

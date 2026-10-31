import Application
import Domain
import GymCoreTesting
import Testing
import ViewModels

// Lo que hace la app al arrancar, al volver y al irse a segundo plano (antes, en GymCompanionApp,
// sin test).

@MainActor
@Suite("El ciclo de vida de la app")
struct AppLifecycleTests {
    private func lifecycle(_ base: AppHarness) -> AppLifecycle {
        AppLifecycle(app: base.app, sync: base.sync, today: TodayModel(app: base.app, clock: base.clock))
    }

    @Test("al arrancar, carga los datos y sincroniza")
    func launch() async {
        let harness = SyncHarness(local: SyncFixtures.base, remote: SyncFixtures.finishedWorkout())
        let repository = harness.repository()
        let app = AppModel(repository: repository)
        let sync = SyncModel(repository: repository, app: app)
        await AppLifecycle(app: app, sync: sync, today: TodayModel(app: app, clock: FixedClock(SyncFixtures.today))).launch()
        #expect(app.data == SyncFixtures.finishedWorkout(), "Lo remoto distinto sustituye a lo local al arrancar")
        #expect(sync.status.state == .ok)
    }

    @Test("al volver a la app sin datos cargados no sincroniza")
    func activeWithoutData() async {
        let harness = SyncHarness()
        let repository = harness.repository()
        let app = AppModel(repository: repository)
        let sync = SyncModel(repository: repository, app: app)
        await AppLifecycle(app: app, sync: sync, today: TodayModel(app: app, clock: FixedClock(SyncFixtures.today))).becameActive()
        #expect(await harness.remote.fetches == 0)
    }

    @Test("el entreno terminado en el reloj, con la app sin arrancar: carga los datos y lo termina")
    func finishedOnWatchBeforeLaunch() async {
        let harness = SyncHarness(local: SyncFixtures.activeWorkout(actual: [10, 10, 8]), remote: SyncFixtures.base)
        let repository = harness.repository()
        let app = AppModel(repository: repository)
        let sync = SyncModel(repository: repository, app: app)
        let lifecycle = AppLifecycle(app: app, sync: sync, today: TodayModel(app: app, clock: FixedClock(SyncFixtures.today)))
        await lifecycle.workoutFinishedOnWatch(on: SyncFixtures.today)
        #expect(await harness.savedLocally?.history.session(on: SyncFixtures.today)?.completed == true)
        #expect(await harness.remote.pushes.last?.data.history.session(on: SyncFixtures.today)?.completed == true)
    }

    @Test("al irse a segundo plano, aplica lo tecleado y sube ya lo pendiente")
    func background() async {
        let harness = SyncHarness()
        let base = await AppHarness.start(harness, repository: harness.repositoryWithoutTimer())
        let today = TodayModel(app: base.app, clock: base.clock)
        let lifecycle = AppLifecycle(app: base.app, sync: base.sync, today: today)
        var changed = SyncFixtures.base
        changed.catalog = Catalog(changed.catalog.all + [Exercise(id: "remo", name: "Remo")])
        await base.app.update(changed)
        #expect(await harness.remote.pushes.isEmpty, "La subida espera a su tiempo")
        await lifecycle.wentToBackground()
        #expect(await harness.background.runs == 1)
        #expect(await harness.remote.pushes.last?.data == changed)
    }
}

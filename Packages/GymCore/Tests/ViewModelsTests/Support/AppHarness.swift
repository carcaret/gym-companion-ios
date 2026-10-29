import Application
import Domain
import GymCoreTesting
import ViewModels

/// Lo que monta cada test de un modelo de pantalla: el repositorio con los dobles de todos los
/// puertos (`SyncHarness`), `AppModel` arrancado y `SyncModel` al día. El reloj, parado en
/// `SyncFixtures.today`.
@MainActor
struct AppHarness {
    let harness: SyncHarness
    let repository: TrainingRepository
    let app: AppModel
    let sync: SyncModel

    static func start(_ harness: SyncHarness, repository: TrainingRepository? = nil) async -> AppHarness {
        let repository = repository ?? harness.repository()
        let app = AppModel(repository: repository)
        let sync = SyncModel(repository: repository, app: app)
        await app.start()
        await sync.refresh()
        return AppHarness(harness: harness, repository: repository, app: app, sync: sync)
    }

    /// Con `data` en local y sin GitHub.
    static func start(local data: TrainingData) async -> AppHarness {
        await start(SyncHarness(local: data, configured: false))
    }

    let clock = FixedClock(SyncFixtures.today)
}

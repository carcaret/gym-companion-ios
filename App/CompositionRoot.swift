import Adapters
import AppleAdapters
import Application
import Domain
import Foundation
import HealthAdapters
import Presentation
import ViewModels
import WatchAdapters

/// Raíz de composición: el único sitio de la app que conoce los adaptadores concretos y los
/// conecta con los casos de uso. Las vistas y los ViewModels reciben lo que necesitan desde aquí.
@MainActor
struct CompositionRoot {
    let appVersion: AppVersion
    let repository: TrainingRepository
    let model: AppModel
    let sync: SyncModel
    let navigation: NavigationModel
    let today: TodayModel
    let history: HistoryModel
    let charts: ChartsModel
    let progress: ProgressModel
    let catalog: CatalogModel
    let settings: SettingsModel

    init(bundle: Bundle = .main, demo: DemoEnvironment = DemoEnvironment()) {
        appVersion = AppVersion(
            marketing: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
        let clock = SystemClock()
        repository = TrainingRepository(
            store: demo.isDemo ? demo.store(today: clock.today()) : Self.store(),
            settings: demo.isDemo ? demo.settings() : Self.settings(),
            credentials: KeychainCredentialStore(),
            remote: GitHubTrainingDataSource(),
            clock: clock,
            background: UIKitBackgroundActivity()
        )
        // Con `-demo` el reloj no recibe nada: los datos de ejemplo no son los del usuario.
        model = AppModel(repository: repository, watch: demo.isDemo ? nil : WatchRelay(publisher: WatchConnectivityPublisher(), clock: clock))
        sync = SyncModel(repository: repository, app: model, noticeDuration: demo.noticeDuration)
        navigation = NavigationModel()
        // Empezar el entreno abre el reloj para que lo mida (en la demo no: no hay reloj).
        today = TodayModel(app: model, clock: clock, watchLauncher: demo.isDemo ? nil : HealthKitWatchLauncher())
        history = HistoryModel(app: model, clock: clock)
        charts = ChartsModel(app: model, clock: clock)
        progress = ProgressModel(app: model, clock: clock)
        catalog = CatalogModel(app: model)
        settings = SettingsModel(sync: sync, repository: repository, version: appVersion)
    }

    /// Cada vez que vuelve la red.
    func reconnections() -> AsyncStream<Void> {
        ConnectivityMonitor.reconnections()
    }

    /// Application Support del iPhone; en el improbable caso de que no exista, la carpeta temporal
    /// (los datos no sobrevivirían, pero la app arranca).
    private static func store() -> any TrainingDataStore {
        (try? JSONFileTrainingDataStore.applicationSupport())
            ?? JSONFileTrainingDataStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("training-data.json"))
    }

    private static func settings() -> any SyncSettingsStore {
        (try? JSONFileSyncSettingsStore.applicationSupport())
            ?? JSONFileSyncSettingsStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("sync.json"))
    }
}

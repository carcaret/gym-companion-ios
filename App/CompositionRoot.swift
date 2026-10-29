import Adapters
import AppleAdapters
import Application
import Domain
import Foundation
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
    /// Lo que dura un aviso: 2,5 s, como el toast de la PWA. Con `-avisos-largos`, 10 s,
    /// para los tests de interfaz que lo buscan tras una animación larga (tirar para sincronizar):
    /// XCUITest espera a que la app se quede quieta y el aviso ya se había ido.
    let noticeDuration: Duration

    init(bundle: Bundle = .main) {
        appVersion = AppVersion(
            marketing: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
        let demo = ProcessInfo.processInfo.arguments.contains("-demo")
        noticeDuration = ProcessInfo.processInfo.arguments.contains("-avisos-largos") ? .seconds(10) : .seconds(2.5)
        repository = TrainingRepository(
            store: demo ? Self.demoStore(unreadable: ProcessInfo.processInfo.arguments.contains("-datos-ilegibles")) : Self.store(),
            settings: demo ? Self.demoSettings() : Self.settings(),
            credentials: KeychainCredentialStore(),
            remote: GitHubTrainingDataSource(),
            clock: SystemClock(),
            background: UIKitBackgroundActivity()
        )
        // Con `-demo` el reloj no recibe nada: los datos de ejemplo no son los del usuario.
        model = AppModel(repository: repository, watch: demo ? nil : WatchRelay(publisher: WatchConnectivityPublisher(), clock: SystemClock()))
        sync = SyncModel(repository: repository, app: model)
        let navigation = NavigationModel()
        self.navigation = navigation
        today = TodayModel(app: model, clock: SystemClock())
        history = HistoryModel(app: model, clock: SystemClock())
        charts = ChartsModel(app: model, clock: SystemClock())
        progress = ProgressModel(app: model, clock: SystemClock())
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

    /// Para las capturas del CI (`-demo`): datos de ejemplo en una carpeta temporal nueva y sin
    /// GitHub. No toca los datos de verdad. Con `-datos-ilegibles`, el fichero está estropeado
    /// (el test de la pantalla de error).
    private static func demoStore(unreadable: Bool) -> any TrainingDataStore {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("demo-\(UUID().uuidString)")
        let file = folder.appendingPathComponent("training-data.json")
        let store = JSONFileTrainingDataStore(file: file)
        if unreadable {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? Data("esto no es un training-data.json".utf8).write(to: file)
            return store
        }
        let data = DemoData.make(today: SystemClock().today())
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            try? await store.save(data)
            semaphore.signal()
        }
        semaphore.wait()
        return store
    }

    private static func demoSettings() -> any SyncSettingsStore {
        JSONFileSyncSettingsStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("demo-\(UUID().uuidString)/sync.json"))
    }

    private static func settings() -> any SyncSettingsStore {
        (try? JSONFileSyncSettingsStore.applicationSupport())
            ?? JSONFileSyncSettingsStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("sync.json"))
    }
}

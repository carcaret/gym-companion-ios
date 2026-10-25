import Adapters
import AppleAdapters
import Application
import Domain
import Foundation
import ViewModels

/// Raíz de composición: el único sitio de la app que conoce los adaptadores concretos y los
/// conecta con los casos de uso. Las vistas y los ViewModels reciben lo que necesitan desde aquí.
@MainActor
struct CompositionRoot {
    let appVersion: AppVersion
    let repository: TrainingRepository
    let model: AppModel
    let sync: SyncModel

    init(bundle: Bundle = .main) {
        appVersion = AppVersion(
            marketing: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
        repository = TrainingRepository(
            store: Self.store(),
            settings: Self.settings(),
            credentials: KeychainCredentialStore(),
            remote: GitHubTrainingDataSource(),
            clock: SystemClock(),
            background: UIKitBackgroundActivity()
        )
        model = AppModel(repository: repository)
        sync = SyncModel(repository: repository, app: model)
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

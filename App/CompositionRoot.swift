import Adapters
import Application
import Domain
import Foundation
import ViewModels

/// Raíz de composición: el único sitio de la app que conoce los adaptadores concretos y los
/// conecta con los casos de uso. Las vistas y los ViewModels reciben lo que necesitan desde aquí.
@MainActor
struct CompositionRoot {
    let appVersion: AppVersion

    init(bundle: Bundle = .main) {
        appVersion = AppVersion(
            marketing: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    /// El estado de la app con sus piezas. La sincronización con GitHub solo se activa si hay
    /// ajustes y token (se meten en Ajustes); sin ellos, todo se guarda igual en el iPhone. La
    /// primera vez, los datos se bajan del `db.json` público de la PWA, sin token.
    func makeModel() async -> AppModel {
        let store = Self.dataStore()
        let settings = await UserDefaultsGitHubSettingsStore().load()
        let token = try? await KeychainCredentialStore().token()
        let remote = settings.flatMap { settings in token.map { GitHubRemote(settings: settings, token: $0) } }
        let synchronizer = Synchronizer(store: store, metadataStore: Self.metadataStore(), remote: remote, clock: SystemClock())
        let startUp = StartUp(store: store, initialSource: GitHubRemote(settings: settings ?? .pwa, token: token))
        return AppModel(startUp: startUp, synchronizer: synchronizer)
    }

    /// Application Support del iPhone; en el improbable caso de que no exista, la carpeta temporal
    /// (los datos no sobrevivirían, pero la app arranca).
    private static func dataStore() -> any TrainingDataStore {
        (try? JSONFileTrainingDataStore.applicationSupport())
            ?? JSONFileTrainingDataStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("training-data.json"))
    }

    private static func metadataStore() -> any SyncMetadataStore {
        (try? JSONFileSyncMetadataStore.applicationSupport())
            ?? JSONFileSyncMetadataStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("sync.json"))
    }
}

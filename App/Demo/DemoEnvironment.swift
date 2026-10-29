import Adapters
import Application
import Domain
import Foundation

/// Lo que cambia al arrancar para las capturas y los tests de interfaz (`LaunchArgument`): datos
/// de ejemplo en una carpeta temporal nueva, sin GitHub y sin tocar los datos de verdad, y avisos
/// más largos. Nunca se usa en el iPhone. Lo usa solo `CompositionRoot`.
struct DemoEnvironment {
    let isDemo: Bool
    let isDataUnreadable: Bool
    let noticeDuration: Duration

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        isDemo = LaunchArgument.demo.isPresent(in: arguments)
        isDataUnreadable = LaunchArgument.unreadableData.isPresent(in: arguments)
        noticeDuration = LaunchArgument.longNotices.isPresent(in: arguments) ? .seconds(10) : .seconds(2.5)
    }

    /// Los datos de ejemplo de hoy; con `-datos-ilegibles`, un fichero estropeado (el test de la
    /// pantalla de error).
    func store(today: LocalDate) -> any TrainingDataStore {
        let folder = Self.temporaryFolder()
        let file = folder.appendingPathComponent("training-data.json")
        let store = JSONFileTrainingDataStore(file: file)
        if isDataUnreadable {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? Data("esto no es un training-data.json".utf8).write(to: file)
        } else {
            try? store.write(DemoData.make(today: today))
        }
        return store
    }

    func settings() -> any SyncSettingsStore {
        JSONFileSyncSettingsStore(file: Self.temporaryFolder().appendingPathComponent("sync.json"))
    }

    private static func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("demo-\(UUID().uuidString)")
    }
}

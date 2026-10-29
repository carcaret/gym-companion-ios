import Application
import Domain

/// Doble de la configuración de la sincronización; las instancias con el mismo `Storage` ven lo
/// mismo, como dos arranques.
public struct InMemorySyncSettingsStore: SyncSettingsStore {
    public actor Storage {
        public private(set) var settings: SyncSettings

        public init(_ settings: SyncSettings = SyncSettings()) {
            self.settings = settings
        }

        func save(_ settings: SyncSettings) {
            self.settings = settings
        }
    }

    public let storage: Storage

    public init(storage: Storage = Storage()) {
        self.storage = storage
    }

    public func load() async throws -> SyncSettings { await storage.settings }
    public func save(_ settings: SyncSettings) async throws { await storage.save(settings) }
}

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

/// Doble del Llavero.
public struct InMemoryCredentialStore: CredentialStore {
    public actor Storage {
        public private(set) var token: String?
        /// Guardar falla, como un Llavero que no deja escribir.
        public private(set) var failsToSave = false

        public init(_ token: String? = nil) {
            self.token = token
        }

        public func failSaving() {
            failsToSave = true
        }

        func set(_ token: String?) throws {
            if failsToSave { throw SaveFailure() }
            self.token = token
        }
    }

    public struct SaveFailure: Error {}

    public let storage: Storage

    public init(storage: Storage = Storage()) {
        self.storage = storage
    }

    public func token() async throws -> String? { await storage.token }
    public func setToken(_ token: String?) async throws { try await storage.set(token) }
}

/// Cuenta las veces que se pidió tiempo en segundo plano y ejecuta el trabajo.
public actor RecordingBackgroundActivity: BackgroundActivity {
    public private(set) var runs = 0

    public init() {}

    public func run(_ work: @escaping @Sendable () async -> Void) async {
        runs += 1
        await work()
    }
}

/// Doble del remoto: un solo fichero con su versión, como el `db.json` de GitHub (subir encima
/// de una versión que no es la actual es un conflicto). Se le pueden programar fallos y retener
/// las peticiones para probar lo que pasa mientras están en vuelo.
public struct InMemoryRemote: RemoteTrainingDataSource {
    public struct Push: Hashable, Sendable {
        public let data: TrainingData
        public let replacing: RemoteVersion?
        public let message: String
    }

    public actor Storage {
        public private(set) var data: TrainingData?
        public private(set) var version: RemoteVersion
        public private(set) var fetches = 0
        /// Las subidas que salieron bien.
        public private(set) var pushes: [Push] = []
        /// Todas las subidas intentadas, también las que fallaron.
        public private(set) var pushAttempts = 0
        private var fetchFailure: RemoteError?
        private var pushFailure: RemoteError?
        private var counter = 0
        private let fetchGate = Gate()
        private let pushGate = Gate()

        public init(_ data: TrainingData? = nil, version: String = "sha_remote") {
            self.data = data
            self.version = RemoteVersion(version)
        }

        /// Los fallos que darán las siguientes peticiones (`nil` = funcionan).
        public func fail(fetch: RemoteError? = nil, push: RemoteError? = nil) {
            fetchFailure = fetch
            pushFailure = push
        }

        /// Alguien cambia el fichero por su cuenta.
        public func replace(with data: TrainingData, version: String) {
            self.data = data
            self.version = RemoteVersion(version)
        }

        public func holdFetches() async { await fetchGate.hold() }
        public func waitForHeldFetch() async { await fetchGate.waitForArrival() }
        public func releaseFetches() async { await fetchGate.release() }
        public func holdPushes() async { await pushGate.hold() }
        public func waitForHeldPush() async { await pushGate.waitForArrival() }
        public func releasePushes() async { await pushGate.release() }

        func fetch() async throws(RemoteError) -> RemoteSnapshot {
            await fetchGate.pass()
            fetches += 1
            if let fetchFailure { throw fetchFailure }
            guard let data else { throw .status(404) }
            return RemoteSnapshot(data: data, version: version)
        }

        func push(_ new: TrainingData, replacing: RemoteVersion?, message: String) async throws(RemoteError) -> RemoteVersion {
            await pushGate.pass()
            pushAttempts += 1
            if let pushFailure { throw pushFailure }
            guard replacing == (data == nil ? nil : version) else { throw .conflict }
            counter += 1
            data = new
            version = RemoteVersion("sha_\(counter)")
            pushes.append(Push(data: new, replacing: replacing, message: message))
            return version
        }
    }

    public let storage: Storage

    public init(storage: Storage) {
        self.storage = storage
    }

    public func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> RemoteSnapshot {
        try await storage.fetch()
    }

    public func push(_ data: TrainingData, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
                     message: String) async throws(RemoteError) -> RemoteVersion {
        try await storage.push(data, replacing: version, message: message)
    }
}

/// Barrera para retener peticiones: mientras está echada, quien pasa espera a que se abra.
actor Gate {
    private var held = false
    private var arrived = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []

    func hold() {
        held = true
        arrived = false
    }

    func release() {
        held = false
        let resumed = waiting
        waiting = []
        resumed.forEach { $0.resume() }
    }

    func pass() async {
        guard held else { return }
        arrived = true
        let arrivals = arrivalWaiters
        arrivalWaiters = []
        arrivals.forEach { $0.resume() }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Espera a que alguien llegue a la barrera echada.
    func waitForArrival() async {
        guard !arrived else { return }
        await withCheckedContinuation { arrivalWaiters.append($0) }
    }
}

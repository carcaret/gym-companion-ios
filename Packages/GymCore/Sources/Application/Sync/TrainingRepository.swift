import Domain

/// Estado del indicador de sincronización.
public enum SyncState: Hashable, Sendable {
    /// GitHub sin configurar.
    case disabled
    /// Todo subido.
    case ok
    /// Hay cambios sin subir (o subiéndose).
    case pending
}

public struct SyncStatus: Hashable, Sendable {
    public var state: SyncState
    /// La última subida chocó con una versión remota que no era la conocida: hay que elegir.
    public var conflict: Bool

    public init(state: SyncState, conflict: Bool = false) {
        self.state = state
        self.conflict = conflict
    }
}

/// Lo que pasa sin que nadie lo pida y la interfaz tiene que saber.
public enum SyncEvent: Hashable, Sendable {
    case status(SyncStatus)
    /// Terminó bien una subida diferida (en la PWA, el toast "Guardado"; la app no avisa).
    case autoSaved
}

public enum UploadResult: Hashable, Sendable {
    case uploaded
    case notConfigured
    /// Hay que resolver el conflicto antes de subir.
    case conflict
    /// Sin red: no se pudo ni preguntar a GitHub.
    case unreachable
    /// GitHub respondió con un error.
    case failed
}

public enum DownloadResult: Hashable, Sendable {
    case applied(TrainingData)
    case notConfigured
    /// Sin red, con error o con un contenido que no es válido: lo local no se toca.
    case failed
}

public enum ConnectionResult: Hashable, Sendable {
    case connected
    case status(Int)
    case unreachable
    /// Conecta, pero el fichero no es un `db.json` válido.
    case invalidContent
}

public enum ConfigureResult: Hashable, Sendable {
    /// La app estaba vacía: se han bajado los datos de GitHub.
    case downloaded(TrainingData)
    /// La app estaba vacía y no se pudo bajar nada (se queda configurada).
    case downloadFailed
    /// Había datos locales: se suben, como hacía la PWA.
    case uploading
}

public enum SyncOutcome: Hashable, Sendable {
    case nothing
    case uploaded
    /// Lo remoto era distinto y no había nada pendiente: sustituye a lo local.
    case remoteApplied(TrainingData)
    case failed
}

/// Los datos del usuario: los guarda en local al momento y los sincroniza con el `db.json` de
/// GitHub con la misma política que la PWA (`src/store.js`, tests de `sync-canonicos.spec.js`):
///
/// - Lo local manda. Cada cambio se guarda y queda "pendiente de subir"; se sube pasado un
///   momento (`uploadDelay`), juntando los cambios seguidos. Con un entreno en curso no se sube
///   nada hasta terminarlo (`saveAndUpload`).
/// - Al arrancar o volver a la app (`synchronize`): si hay algo pendiente, se sube; si no, y no
///   hay entreno en curso, lo remoto distinto sustituye a lo local (alguien editó `db.json`).
/// - Subir encima de una versión remota que no es la conocida es un conflicto: no se sube nada
///   hasta que el usuario elige qué versión se queda (`keepLocal` o `download`).
///
/// Mejoras sobre la PWA: las subidas van de una en una (dos a la vez daban un falso conflicto)
/// y un cambio hecho mientras se sube sigue pendiente.
public actor TrainingRepository {
    private let store: any TrainingDataStore
    private let settingsStore: any SyncSettingsStore
    private let credentials: any CredentialStore
    private let remote: any RemoteTrainingDataSource
    private let clock: any Clock
    private let background: any BackgroundActivity
    private let uploadDelay: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    public private(set) var data = TrainingData()
    public private(set) var status = SyncStatus(state: .disabled)
    private var settings = SyncSettings()
    private var token: String?
    /// El `sha` remoto conocido; solo en memoria, como en la PWA.
    private var version: RemoteVersion?
    /// Cuenta los cambios, para saber si lo subido es lo último.
    private var revision = 0
    private var scheduledUpload: Task<Void, Never>?
    private var runningUpload: Task<UploadResult, Never>?

    /// Para un solo oyente (el ViewModel de la sincronización).
    public nonisolated let events: AsyncStream<SyncEvent>
    private let continuation: AsyncStream<SyncEvent>.Continuation

    public init(
        store: any TrainingDataStore, settings: any SyncSettingsStore, credentials: any CredentialStore,
        remote: any RemoteTrainingDataSource, clock: any Clock, background: any BackgroundActivity,
        uploadDelay: Duration = .milliseconds(500),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        settingsStore = settings
        self.credentials = credentials
        self.remote = remote
        self.clock = clock
        self.background = background
        self.uploadDelay = uploadDelay
        self.sleep = sleep
        (events, continuation) = AsyncStream.makeStream()
    }

    // MARK: - Arranque

    /// Los datos guardados; la primera vez, los de GitHub si está configurado, o los iniciales.
    /// Lanza si lo guardado no se puede leer (no hay que machacarlo).
    public func start() async throws -> TrainingData {
        settings = try await settingsStore.load()
        token = try? await credentials.token()
        setStatus(state: target == nil ? .disabled : settings.hasPendingUpload ? .pending : .ok)
        data = try await StartUp(store: store, initialData: { await self.remoteInitialData() }).run()
        return data
    }

    private func remoteInitialData() async -> TrainingData? {
        guard let target, let snapshot = try? await remote.fetch(target.location, token: target.token) else { return nil }
        version = snapshot.version
        return snapshot.data
    }

    /// Al arrancar, al volver a la app o al volver la red: sube lo pendiente o, si no hay nada
    /// pendiente, aplica lo remoto si es distinto. Con un conflicto abierto o un entreno en curso
    /// no hace nada.
    public func synchronize() async -> SyncOutcome {
        guard target != nil, !status.conflict else { return .nothing }
        if settings.hasPendingUpload {
            guard !isWorkoutActive else { return .nothing }
            return await upload() == .uploaded ? .uploaded : .failed
        }
        return await pullIfClean().map { .remoteApplied($0) } ?? .nothing
    }

    /// `pullFromGitHubIfClean`: lo remoto sustituye a lo local solo si no hay nada pendiente ni
    /// entreno en curso, antes y después de preguntar (el usuario puede editar mientras tanto).
    private func pullIfClean() async -> TrainingData? {
        guard let target, isClean else { return nil }
        let before = revision
        guard let snapshot = try? await remote.fetch(target.location, token: target.token) else { return nil }
        guard isClean, revision == before else { return nil }
        version = snapshot.version
        guard snapshot.data != data else { return nil }
        await apply(snapshot.data)
        return data
    }

    private var isClean: Bool { !settings.hasPendingUpload && !isWorkoutActive }

    // MARK: - Cambios

    /// Guarda un cambio y deja programada la subida (salvo con un entreno en curso).
    public func update(_ newData: TrainingData) async throws {
        try await saveLocally(newData)
        guard !isWorkoutActive, target != nil else { return }
        scheduleUpload()
    }

    /// Guarda un cambio y lo sube ya (al terminar un entreno).
    @discardableResult
    public func saveAndUpload(_ newData: TrainingData) async throws -> UploadResult {
        try await saveLocally(newData)
        cancelScheduledUpload()
        return await upload()
    }

    private func saveLocally(_ newData: TrainingData) async throws {
        data = newData
        revision += 1
        if !settings.hasPendingUpload {
            settings.hasPendingUpload = true
            try await settingsStore.save(settings)
        }
        try await store.save(newData)
        if target != nil { setStatus(state: .pending) }
    }

    private func scheduleUpload() {
        scheduledUpload?.cancel()
        scheduledUpload = Task { [uploadDelay, sleep] in
            do { try await sleep(uploadDelay) } catch { return }
            await self.runScheduledUpload()
        }
    }

    private func runScheduledUpload() async {
        guard !Task.isCancelled else { return }
        scheduledUpload = nil
        if await upload() == .uploaded { continuation.yield(.autoSaved) }
    }

    private func cancelScheduledUpload() {
        scheduledUpload?.cancel()
        scheduledUpload = nil
    }

    /// Al pasar a segundo plano: la subida programada sale ya, con tiempo pedido al sistema.
    public func flush() async {
        guard scheduledUpload != nil else { return }
        cancelScheduledUpload()
        await background.run { [self] in _ = await upload() }
    }

    // MARK: - Subir

    /// Botón "Subir a GitHub".
    public func forceUpload() async -> UploadResult {
        guard target != nil else { return .notConfigured }
        guard !status.conflict else { return .conflict }
        cancelScheduledUpload()
        return await upload()
    }

    /// Conflicto → "Subir local → GitHub": se pregunta la versión actual y se sube encima.
    public func keepLocal() async -> UploadResult {
        guard let target else { return .notConfigured }
        do {
            version = try await remote.fetch(target.location, token: target.token).version
        } catch .unreachable {
            return .unreachable
        } catch {
            return .failed
        }
        status.conflict = false
        return await upload()
    }

    /// `saveDBToGitHub`, de una en una.
    private func upload() async -> UploadResult {
        let previous = runningUpload
        let task = Task {
            _ = await previous?.value
            return await self.performUpload()
        }
        runningUpload = task
        let result = await task.value
        if runningUpload == task { runningUpload = nil }
        return result
    }

    private func performUpload() async -> UploadResult {
        guard let target else { return .notConfigured }
        setStatus(state: .pending)
        if version == nil {
            // Sin sha, el PUT daría un 422 que parecería un conflicto (Canónico M).
            do {
                version = try await remote.fetch(target.location, token: target.token).version
            } catch .unreachable {
                return .unreachable
            } catch .status(404) {
                // El fichero aún no existe: se crea.
            } catch {
                return .failed
            }
        }
        let snapshot = data
        let snapshotRevision = revision
        do {
            version = try await remote.push(snapshot, to: target.location, token: target.token, replacing: version,
                                            message: "Gym Companion update \(clock.today().iso)")
        } catch .conflict {
            setStatus(state: .pending, conflict: true)
            return .conflict
        } catch .unreachable {
            return .unreachable
        } catch {
            return .failed
        }
        if revision == snapshotRevision {
            settings.hasPendingUpload = false
            try? await settingsStore.save(settings)
        }
        setStatus(state: settings.hasPendingUpload ? .pending : .ok, conflict: false)
        return .uploaded
    }

    // MARK: - Bajar

    /// Botón "Descargar de GitHub" y conflicto → "Bajar GitHub → local": lo remoto sustituye a lo
    /// local, aunque hubiera algo pendiente.
    public func download() async -> DownloadResult {
        guard let target else { return .notConfigured }
        guard let snapshot = try? await remote.fetch(target.location, token: target.token) else { return .failed }
        version = snapshot.version
        await apply(snapshot.data)
        return .applied(data)
    }

    /// `applyRemoteDB`.
    private func apply(_ remoteData: TrainingData) async {
        cancelScheduledUpload()
        data = remoteData
        revision += 1
        try? await store.save(remoteData)
        settings.hasPendingUpload = false
        try? await settingsStore.save(settings)
        setStatus(state: .ok, conflict: false)
    }

    // MARK: - Configuración

    /// Lo guardado, para rellenar Ajustes (la PWA enseña el token en claro en su campo).
    public var configuration: (location: SyncLocation?, token: String?) {
        (settings.location, token)
    }

    /// Botón "Probar conexión": pregunta a GitHub sin tocar los datos.
    public func testConnection(_ location: SyncLocation, token: String) async -> ConnectionResult {
        do {
            _ = try await remote.fetch(location, token: token)
            return .connected
        } catch {
            switch error {
            case .status(let code): return .status(code)
            case .unreachable: return .unreachable
            case .invalidContent: return .invalidContent
            case .conflict: return .status(409)
            }
        }
    }

    /// Guarda dónde está el `db.json` y el token. Con la app vacía (recién instalada) baja los
    /// datos de GitHub; la PWA subía los locales, y aquí eso machacaría los datos de verdad con
    /// nada. Con datos locales, los sube, como la PWA.
    public func configure(_ location: SyncLocation, token newToken: String) async throws -> ConfigureResult {
        try await credentials.setToken(newToken)
        token = newToken
        settings.location = location
        try await settingsStore.save(settings)
        version = nil
        status.conflict = false
        if data.history.isEmpty && data.catalog.ids.isEmpty {
            setStatus(state: .ok)
            if case .applied(let remoteData) = await download() { return .downloaded(remoteData) }
            return .downloadFailed
        }
        if let snapshot = try? await remote.fetch(location, token: newToken) { version = snapshot.version }
        try await update(data)
        return .uploading
    }

    // MARK: - Ayudas

    private var target: (location: SyncLocation, token: String)? {
        guard let location = settings.location, let token, !token.isEmpty else { return nil }
        return (location, token)
    }

    private var isWorkoutActive: Bool {
        data.history.isWorkoutActive(on: clock.today())
    }

    private func setStatus(state: SyncState, conflict: Bool? = nil) {
        let new = SyncStatus(state: target == nil ? .disabled : state, conflict: conflict ?? status.conflict)
        guard new != status else { return }
        status = new
        continuation.yield(.status(new))
    }
}

import Domain

/// Estado de la sincronización, el del indicador.
public enum SyncStatus: Hashable, Sendable {
    /// Sin GitHub configurado.
    case disabled
    /// Todo subido.
    case ok
    /// Hay cambios sin subir (sin red, entreno en curso, error…).
    case pending
    /// Sin subir porque GitHub cambió por su lado (p. ej. `db.json` editado a mano): hay que elegir.
    case conflict
}

/// Lo que pasa en segundo plano y la interfaz tiene que saber.
public enum SyncEvent: Sendable {
    case status(SyncStatus)
    /// Se subió tras un guardado ("Guardado").
    case uploaded
    /// Al arrancar se aplicaron datos de GitHub más nuevos ("Datos actualizados desde GitHub").
    case remoteApplied(TrainingData)
}

/// Resultado de subir o bajar a mano.
public enum SyncResult: Hashable, Sendable {
    case done
    /// GitHub no configurado (o sin token).
    case notConfigured
    case conflict
    case failed(RemoteError)
}

/// Sincroniza los datos locales con el remoto (el `db.json` de GitHub) con la política de la PWA.
///
/// - Lo local manda: cada cambio se guarda en el aparato al momento y queda pendiente de subir.
/// - La subida espera medio segundo (si llegan más cambios, sube solo el último) y nunca ocurre
///   con un entreno en curso: se sube al terminarlo (`uploadNow`).
/// - Al arrancar, si hay pendiente se sube; si no, se baja lo remoto y, si es distinto, se aplica
///   (salvo que mientras tanto haya un cambio local o un entreno en curso).
/// - Si GitHub cambió por su lado, la subida da conflicto y no se toca nada hasta que el usuario
///   elige (`keepLocal` o `downloadRemote`).
/// - Al ir a segundo plano, `flush()` sube lo que estuviera esperando.
public actor Synchronizer {
    public private(set) var status: SyncStatus
    public nonisolated let events: AsyncStream<SyncEvent>

    private let store: any TrainingDataStore
    private let metadataStore: any SyncMetadataStore
    private let remote: (any RemoteTrainingData)?
    private let clock: any Clock
    private let debounce: Duration
    private let sleep: Sleep
    private let continuation: AsyncStream<SyncEvent>.Continuation

    private var metadata = SyncMetadata()
    private var latest: TrainingData?
    private var scheduledUpload: Task<Void, Never>?

    /// `remote` es `nil` si GitHub no está configurado: los cambios se guardan igual, en local.
    public init(
        store: any TrainingDataStore, metadataStore: any SyncMetadataStore, remote: (any RemoteTrainingData)?,
        clock: any Clock, debounce: Duration = .milliseconds(500), sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        self.metadataStore = metadataStore
        self.remote = remote
        self.clock = clock
        self.debounce = debounce
        self.sleep = sleep
        status = remote == nil ? .disabled : .ok
        (events, continuation) = AsyncStream.makeStream()
    }

    /// Arranque, con los datos ya cargados en local.
    public func start(with local: TrainingData) async {
        latest = local
        metadata = (try? await metadataStore.load()) ?? SyncMetadata()
        guard remote != nil else { return set(.disabled) }
        if metadata.needsUpload {
            set(.pending)
            await upload()
        } else {
            set(.ok)
            await pullIfClean()
        }
    }

    /// Un cambio local: se guarda ya y se sube en un momento (salvo con un entreno en curso).
    public func save(_ data: TrainingData) async throws {
        latest = data
        try await store.save(data)
        metadata.needsUpload = true
        try await metadataStore.save(metadata)
        guard remote != nil, !isWorkoutActive else { return }
        scheduledUpload?.cancel()
        scheduledUpload = Task { [debounce, sleep] in
            do { try await sleep(debounce) } catch { return }
            await self.scheduledUploadFired()
        }
    }

    /// Sube ya lo último guardado (al terminar un entreno, o con "Subir a GitHub").
    @discardableResult
    public func uploadNow() async -> SyncResult {
        guard remote != nil else { return .notConfigured }
        if status == .conflict { return .conflict }
        scheduledUpload?.cancel()
        scheduledUpload = nil
        set(.pending)
        return await upload()
    }

    /// La app pasa a segundo plano: lo que esperaba para subir, se sube ya.
    public func flush() async {
        guard scheduledUpload != nil else { return }
        scheduledUpload?.cancel()
        scheduledUpload = nil
        await upload()
    }

    /// Ha vuelto la red o la app al primer plano: si quedó algo por subir (y no hay conflicto ni
    /// entreno en curso), se reintenta.
    public func retryIfPending() async {
        guard remote != nil, metadata.needsUpload, status != .conflict, !isWorkoutActive else { return }
        await upload()
    }

    /// Conflicto resuelto a favor de lo local: se sube encima de lo que haya en GitHub.
    @discardableResult
    public func keepLocal() async -> SyncResult {
        guard let remote else { return .notConfigured }
        do {
            metadata.revision = try await remote.fetch().revision
        } catch {
            return .failed(error)
        }
        return await upload()
    }

    /// Lo de GitHub sustituye a lo local (con "Bajar GitHub → local" o "Sincronizar desde
    /// GitHub"): lo no subido se pierde. Devuelve los datos nuevos.
    public func downloadRemote() async -> Result<TrainingData, RemoteError> {
        guard let remote else { return .failure(.unauthorized) }
        do {
            let snapshot = try await remote.fetch()
            await apply(snapshot)
            return .success(snapshot.data)
        } catch {
            return .failure(error)
        }
    }

    // MARK: -

    private var isWorkoutActive: Bool {
        latest?.history.isWorkoutActive(on: clock.today()) ?? false
    }

    private func scheduledUploadFired() async {
        guard !Task.isCancelled else { return }
        scheduledUpload = nil
        set(.pending)
        if await upload() == .done { continuation.yield(.uploaded) }
    }

    @discardableResult
    private func upload() async -> SyncResult {
        guard let remote, let data = latest else { return .notConfigured }
        if metadata.revision == nil {
            // Sin revisión no se puede subir encima: se pide antes (si falla, queda pendiente).
            do {
                metadata.revision = try await remote.fetch().revision
            } catch {
                set(.pending)
                return .failed(error)
            }
        }
        do {
            metadata.revision = try await remote.push(data, over: metadata.revision, message: "Gym Companion update \(clock.today().iso)")
            metadata.needsUpload = latest != data
            try? await metadataStore.save(metadata)
            set(metadata.needsUpload ? .pending : .ok)
            return .done
        } catch .conflict {
            set(.conflict)
            return .conflict
        } catch {
            set(.pending)
            return .failed(error)
        }
    }

    /// Baja lo remoto y lo aplica si es distinto, salvo que haya algo local pendiente o un
    /// entreno en curso (antes y después de bajarlo: pudo cambiar mientras tanto).
    private func pullIfClean() async {
        guard let remote, !metadata.needsUpload, !isWorkoutActive else { return }
        guard let snapshot = try? await remote.fetch() else { return }
        guard !metadata.needsUpload, !isWorkoutActive else { return }
        metadata.revision = snapshot.revision
        try? await metadataStore.save(metadata)
        guard snapshot.data != latest else { return }
        await apply(snapshot)
        continuation.yield(.remoteApplied(snapshot.data))
    }

    // Fuera de `save`, guardar los metadatos no puede fallar hacia nadie: si fallara, lo peor es
    // repetir una subida o una bajada en el siguiente arranque, nunca perder datos locales.
    private func apply(_ snapshot: RemoteSnapshot) async {
        latest = snapshot.data
        try? await store.save(snapshot.data)
        metadata = SyncMetadata(needsUpload: false, revision: snapshot.revision)
        try? await metadataStore.save(metadata)
        set(.ok)
    }

    private func set(_ new: SyncStatus) {
        guard new != status else { return }
        status = new
        continuation.yield(.status(new))
    }
}

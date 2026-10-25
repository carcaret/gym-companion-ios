import Application
import Domain

/// Reloj fijo.
public struct FixedClock: Clock {
    public let date: LocalDate

    public init(_ date: LocalDate) {
        self.date = date
    }

    public func today() -> LocalDate { date }
}

/// `SyncMetadataStore` en memoria.
public actor InMemorySyncMetadataStore: SyncMetadataStore {
    public private(set) var metadata: SyncMetadata

    public init(_ metadata: SyncMetadata = SyncMetadata()) {
        self.metadata = metadata
    }

    public func load() async throws -> SyncMetadata { metadata }
    public func save(_ metadata: SyncMetadata) async throws { self.metadata = metadata }
}

/// Remoto falso con la semántica de GitHub: cada subida crea una revisión nueva y subir encima
/// de una revisión que no es la actual es un conflicto. Se le puede pedir que falle.
public actor FakeRemoteTrainingData: RemoteTrainingData {
    public private(set) var snapshot: RemoteSnapshot?
    public var fetchError: RemoteError?
    public var pushError: RemoteError?
    public private(set) var fetches = 0
    /// Cada subida: los datos, la revisión de encima y el mensaje.
    public private(set) var pushes: [(data: TrainingData, over: String?, message: String)] = []
    /// Lo que se ejecuta durante un `fetch`, antes de responder (p. ej. editar en local).
    private var duringFetch: (@Sendable () async -> Void)?
    private var revisions = 0

    public init(_ data: TrainingData? = nil, revision: String = "sha_remote") {
        snapshot = data.map { RemoteSnapshot(data: $0, revision: revision) }
    }

    public func set(_ data: TrainingData, revision: String) { snapshot = RemoteSnapshot(data: data, revision: revision) }
    public func failFetches(with error: RemoteError?) { fetchError = error }
    public func failPushes(with error: RemoteError?) { pushError = error }
    public func onFetch(_ action: @escaping @Sendable () async -> Void) { duringFetch = action }

    public func fetch() async throws(RemoteError) -> RemoteSnapshot {
        fetches += 1
        if let duringFetch { await duringFetch() }
        if let fetchError { throw fetchError }
        guard let snapshot else { throw .notFound }
        return snapshot
    }

    public func push(_ data: TrainingData, over revision: String?, message: String) async throws(RemoteError) -> String {
        pushes.append((data, revision, message))
        if let pushError { throw pushError }
        if let current = snapshot?.revision, revision != current { throw .conflict }
        revisions += 1
        let new = "sha_\(revisions)"
        snapshot = RemoteSnapshot(data: data, revision: new)
        return new
    }
}

/// `sleep` controlado por el test: se queda esperando hasta `advance()` (o hasta que cancelen la
/// tarea, como el `Task.sleep` de verdad).
public actor ManualSleeper {
    private var waiting: [CheckedContinuation<Void, Error>] = []

    public init() {}

    public nonisolated var sleep: Sleep {
        { _ in try await self.wait() }
    }

    /// Despierta a todos los que esperan y deja que acaben lo que hacen detrás. Antes da tiempo a
    /// que las tareas recién creadas lleguen a dormirse.
    public func advance() async {
        for _ in 0..<100 { await Task.yield() }
        let woken = waiting
        waiting = []
        woken.forEach { $0.resume() }
        for _ in 0..<50 { await Task.yield() }
    }

    public var sleepers: Int { waiting.count }

    private func wait() async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { waiting.append($0) }
        try Task.checkCancellation()
    }
}

/// `CredentialStore` en memoria.
public actor InMemoryCredentialStore: CredentialStore {
    private var stored: String?

    public init(_ token: String? = nil) {
        stored = token
    }

    public func token() async throws -> String? { stored }
    public func setToken(_ token: String?) async throws { stored = token }
}

/// `GitHubSettingsStore` en memoria.
public actor InMemoryGitHubSettingsStore: GitHubSettingsStore {
    private var stored: GitHubSettings?

    public init(_ settings: GitHubSettings? = nil) {
        stored = settings
    }

    public func load() async -> GitHubSettings? { stored }
    public func save(_ settings: GitHubSettings?) async { stored = settings }
}

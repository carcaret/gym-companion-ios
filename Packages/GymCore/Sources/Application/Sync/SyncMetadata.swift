/// Lo que la sincronización recuerda entre arranques.
public struct SyncMetadata: Hashable, Sendable {
    /// Hay cambios locales sin subir. (`needsUpload` en la PWA.)
    public var needsUpload: Bool
    /// La revisión del remoto sobre la que están los datos locales (el `sha` de GitHub).
    public var revision: String?

    public init(needsUpload: Bool = false, revision: String? = nil) {
        self.needsUpload = needsUpload
        self.revision = revision
    }
}

/// Puerto donde se guarda `SyncMetadata`.
public protocol SyncMetadataStore: Sendable {
    /// Sin nada guardado, `SyncMetadata()`.
    func load() async throws -> SyncMetadata
    func save(_ metadata: SyncMetadata) async throws
}

/// Una espera (`Task.sleep`); se inyecta para que los tests no esperen de verdad.
public typealias Sleep = @Sendable (Duration) async throws -> Void

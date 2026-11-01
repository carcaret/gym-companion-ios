import Domain

/// Caso de uso: lo de Salud (pesajes, cintura y nutrición), en el `salud.json` de GitHub, junto al
/// `db.json` y con el mismo token, para analizarlo (#104). Salud manda: se rehace entero cada vez y
/// se sube solo si ha cambiado, sin fusionar nada. No toca la sincronización de los entrenos: es
/// otro fichero, con su propia versión.
///
/// Se lanza al arrancar y al volver a la app; si ya está en marcha, se espera a esa vez.
public actor HealthExport {
    public static let fileName = "salud.json"

    private let source: any HealthSampleSource
    private let remote: any RemoteHealthRecordStore
    private let repository: TrainingRepository
    private let clock: any Clock

    /// Lo último que se sabe que hay en GitHub; solo en memoria. Con él, si Salud no ha cambiado no
    /// se pregunta a GitHub.
    private var published: (location: SyncLocation, record: HealthRecord, version: RemoteVersion)?
    private var running: Task<HealthExportResult, Never>?

    public init(source: any HealthSampleSource, remote: any RemoteHealthRecordStore, repository: TrainingRepository,
                clock: any Clock) {
        self.source = source
        self.remote = remote
        self.repository = repository
        self.clock = clock
    }

    public func run() async -> HealthExportResult {
        if let running { return await running.value }
        let task = Task { await self.export() }
        running = task
        let result = await task.value
        running = nil
        return result
    }

    private func export() async -> HealthExportResult {
        guard let target = await repository.syncTarget else { return .notConfigured }
        let record: HealthRecord
        do throws(HealthReadError) {
            record = HealthRecord(samples: try await source.samples())
        } catch {
            return .unreadable(error)
        }
        guard !record.isEmpty else { return .empty }
        let location = target.location.sibling(named: Self.fileName)
        let known = published.flatMap { $0.location == location ? $0 : nil }
        if let known, known.record == record { return .upToDate(record.summary) }
        do throws(RemoteError) {
            let current: (record: HealthRecord, version: RemoteVersion)?
            if let known {
                current = (known.record, known.version)
            } else {
                current = try await remoteVersion(at: location, token: target.token)
            }
            if let current, current.record == record {
                published = (location, record, current.version)
                return .upToDate(record.summary)
            }
            let version = try await remote.push(record, to: location, token: target.token, replacing: current?.version,
                                                on: clock.today())
            published = (location, record, version)
            return .uploaded(record.summary)
        } catch {
            // Lo de GitHub ya no es lo que se creía: la próxima vez se pregunta.
            published = nil
            return .failed(error)
        }
    }

    /// Lo que hay en GitHub; `nil` si el fichero aún no existe.
    private func remoteVersion(at location: SyncLocation, token: String) async throws(RemoteError)
        -> (record: HealthRecord, version: RemoteVersion)? {
        do {
            let snapshot = try await remote.fetch(location, token: token)
            return (snapshot.record, snapshot.version)
        } catch .notFound {
            return nil
        }
    }
}

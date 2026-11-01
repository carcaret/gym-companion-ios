import Domain

/// El `salud.json` remoto y su versión.
public struct RemoteHealthSnapshot: Hashable, Sendable {
    public var record: HealthRecord
    public var version: RemoteVersion

    public init(record: HealthRecord, version: RemoteVersion) {
        self.record = record
        self.version = version
    }
}

/// Puerto: dónde se guarda lo de Salud para analizarlo (el `salud.json` de GitHub, junto al
/// `db.json`). Las mismas reglas de versión que `RemoteTrainingDataSource`.
public protocol RemoteHealthRecordStore: Sendable {
    func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> RemoteHealthSnapshot

    /// Sube encima de `version` (`nil` = el fichero aún no existe) y devuelve la nueva. `day`:
    /// cuándo se sube (en GitHub, va en el mensaje del commit).
    func push(_ record: HealthRecord, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
              on day: LocalDate) async throws(RemoteError) -> RemoteVersion
}

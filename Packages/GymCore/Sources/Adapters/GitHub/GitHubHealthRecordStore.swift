import Application
import Domain
import Foundation

/// El `salud.json` de un repositorio de GitHub (#104), junto al `db.json`, con la API de contenidos.
public struct GitHubHealthRecordStore: RemoteHealthRecordStore {
    private let api: GitHubAPI

    public init(transport: any HTTPTransport = URLSessionTransport()) {
        api = GitHubAPI(transport: transport)
    }

    public func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> RemoteHealthSnapshot {
        let file = try await api.fetch(location, token: token)
        guard let record = HealthRecordFormat.record(from: file.content) else { throw .invalidContent }
        return RemoteHealthSnapshot(record: record, version: file.version)
    }

    public func push(_ record: HealthRecord, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
                     on day: LocalDate) async throws(RemoteError) -> RemoteVersion {
        try await api.push(HealthRecordFormat.json(from: record), to: location, token: token, replacing: version,
                           message: "Salud update \(day.iso)")
    }
}

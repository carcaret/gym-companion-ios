import Application
import Domain
import Foundation

/// El `db.json` de un repositorio de GitHub, leído y escrito con la API de contenidos, como la
/// PWA (`src/store.js`): el mismo fichero, en el mismo formato, para que las dos convivan.
public struct GitHubTrainingDataSource: RemoteTrainingDataSource {
    private let api: GitHubAPI

    public init(transport: any HTTPTransport = URLSessionTransport()) {
        api = GitHubAPI(transport: transport)
    }

    public func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> RemoteSnapshot {
        let file = try await api.fetch(location, token: token)
        guard let data = try? PWAFormat.trainingData(from: file.content) else { throw .invalidContent }
        return RemoteSnapshot(data: data, version: file.version)
    }

    public func push(_ data: TrainingData, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
                     on day: LocalDate) async throws(RemoteError) -> RemoteVersion {
        try await api.push(PWAFormat.json(from: data), to: location, token: token, replacing: version,
                           message: "Gym Companion update \(day.iso)")
    }
}

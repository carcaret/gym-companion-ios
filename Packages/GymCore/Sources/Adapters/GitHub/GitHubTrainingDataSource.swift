import Application
import Domain
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// El `db.json` de un repositorio de GitHub, leído y escrito con la API de contenidos, como la
/// PWA (`src/store.js`): el mismo fichero, en el mismo formato, para que las dos convivan.
public struct GitHubTrainingDataSource: RemoteTrainingDataSource {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> RemoteSnapshot {
        var components = URLComponents(url: try contentsURL(location), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ref", value: location.branch)]
        // Una ruta que no forma una URL no puede existir en el remoto.
        guard let url = components?.url else { throw .notFound }
        let (body, status) = try await send(request(url, token: token))
        guard (200..<300).contains(status) else { throw Self.error(status: status) }
        guard let file = GitHubContents.parse(body), let sha = file.sha,
              let data = try? PWAFormat.trainingData(from: file.content)
        else { throw .invalidContent }
        return RemoteSnapshot(data: data, version: RemoteVersion(sha))
    }

    public func push(_ data: TrainingData, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
                     on day: LocalDate) async throws(RemoteError) -> RemoteVersion {
        var request = request(try contentsURL(location), token: token)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = GitHubContents.payload(for: PWAFormat.json(from: data), sha: version?.rawValue, branch: location.branch,
                                              message: "Gym Companion update \(day.iso)")
        request.httpBody = try? JSONEncoder().encode(payload)
        let (body, status) = try await send(request)
        guard (200..<300).contains(status) else { throw Self.error(status: status) }
        struct Response: Decodable {
            struct Content: Decodable { var sha: String }
            var content: Content
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: body) else { throw .invalidContent }
        return RemoteVersion(response.content.sha)
    }

    /// `https://api.github.com/repos/{repo}/contents/{path}`; el repo y la ruta llevan "/" y van tal cual.
    /// Si no forma una URL (un repo con espacios), no puede existir en el remoto: `.notFound`.
    private func contentsURL(_ location: SyncLocation) throws(RemoteError) -> URL {
        let path = location.path.split(separator: "/").map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
        guard let url = URL(string: "https://api.github.com/repos/\(location.repository)/contents/\(path.joined(separator: "/"))") else {
            throw .notFound
        }
        return url
    }

    private func request(_ url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func send(_ request: URLRequest) async throws(RemoteError) -> (Data, Int) {
        do {
            return try await transport.send(request)
        } catch {
            throw .unreachable
        }
    }

    /// Lo que quiere decir cada código de error de la API de GitHub.
    static func error(status: Int) -> RemoteError {
        switch status {
        case 401, 403: .unauthorized
        case 404: .notFound
        case 409, 422: .conflict
        default: .failed(status: status)
        }
    }
}

import Application
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Leer y escribir un fichero de un repositorio con la API de contenidos de GitHub, como la PWA
/// (`src/store.js`): lo comparten el `db.json` (`GitHubTrainingDataSource`) y el `salud.json`
/// (`GitHubHealthRecordStore`), que solo traducen su contenido.
struct GitHubAPI: Sendable {
    let transport: any HTTPTransport

    /// El fichero, con su `sha`. `.invalidContent` si no es JSON.
    func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> (content: Data, version: RemoteVersion) {
        var components = URLComponents(url: try contentsURL(location), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ref", value: location.branch)]
        // Una ruta que no forma una URL no puede existir en el remoto.
        guard let url = components?.url else { throw .notFound }
        let (body, status) = try await send(request(url, token: token))
        guard (200..<300).contains(status) else { throw Self.error(status: status) }
        guard let file = GitHubContents.parse(body), let sha = file.sha else { throw .invalidContent }
        return (file.content, RemoteVersion(sha))
    }

    /// Sube `content` encima de `version` (`nil` = crearlo) y devuelve la nueva.
    func push(_ content: Data, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
              message: String) async throws(RemoteError) -> RemoteVersion {
        var request = request(try contentsURL(location), token: token)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = GitHubContents.payload(for: content, sha: version?.rawValue, branch: location.branch, message: message)
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

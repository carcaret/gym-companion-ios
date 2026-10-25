import Application
import Domain
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// El `db.json` de un repo de GitHub por la API "contents", como la PWA: GET para leer (con el
/// `sha` del fichero como revisión) y PUT con ese `sha` para escribir; si el fichero cambió
/// entretanto, GitHub responde 409 o 422.
///
/// Ojo: esta API deja de devolver el contenido de ficheros de más de 1 MB.
public struct GitHubRemote: RemoteTrainingData {
    private let settings: GitHubSettings
    private let token: String?
    private let http: any HTTPTransport

    public init(settings: GitHubSettings, token: String?, http: any HTTPTransport = URLSessionTransport()) {
        self.settings = settings
        self.token = token
        self.http = http
    }

    public func fetch() async throws(RemoteError) -> RemoteSnapshot {
        var components = URLComponents(url: contentsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ref", value: settings.branch)]
        let (body, status) = try await send(request(url: components?.url ?? contentsURL, method: "GET"))
        try Self.check(status, conflictIsError: false)
        return try GitHubContents.snapshot(from: body)
    }

    public func push(_ data: TrainingData, over revision: String?, message: String) async throws(RemoteError) -> String {
        guard token != nil else { throw .unauthorized }
        var request = request(url: contentsURL, method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = GitHubContents.payload(for: data, sha: revision, branch: settings.branch, message: message)
        let (body, status) = try await send(request)
        try Self.check(status, conflictIsError: true)
        guard let response = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let sha = (response["content"] as? [String: Any])?["sha"] as? String else { throw .invalidContent }
        return sha
    }

    private var contentsURL: URL {
        URL(string: "https://api.github.com/repos/\(settings.repository)/contents/\(settings.path)")!
    }

    private func request(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func send(_ request: URLRequest) async throws(RemoteError) -> (Data, Int) {
        do {
            return try await http.send(request)
        } catch {
            throw .unavailable
        }
    }

    private static func check(_ status: Int, conflictIsError: Bool) throws(RemoteError) {
        switch status {
        case 200...299: return
        case 401, 403: throw .unauthorized
        case 404: throw .notFound
        case 409, 422 where conflictIsError: throw .conflict
        default: throw .http(status)
        }
    }
}

/// El formato de la API "contents": el fichero va en base64 y con su `sha`.
public enum GitHubContents {
    /// Cuerpo del PUT: `db.json` en base64 (UTF-8), la rama, el mensaje del commit y, si se
    /// conoce, el `sha` encima del que se escribe. (`buildGitHubPayload`.)
    public static func payload(for data: TrainingData, sha: String?, branch: String, message: String) -> Data {
        var body: [String: String] = ["message": message, "content": PWAFormat.json(from: data).base64EncodedString(), "branch": branch]
        if let sha { body["sha"] = sha }
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }

    /// Respuesta del GET: el `db.json` (base64, con saltos de línea) y su `sha`. Sin contenido,
    /// con otra codificación, sin `sha` o con un `db.json` dañado → `invalidContent`.
    /// (`parseGitHubResponse`.)
    public static func snapshot(from response: Data) throws(RemoteError) -> RemoteSnapshot {
        guard let fields = try? JSONSerialization.jsonObject(with: response, options: [.fragmentsAllowed]) as? [String: Any],
              let content = fields["content"] as? String,
              (fields["encoding"] as? String ?? "base64") == "base64",
              let sha = fields["sha"] as? String,
              let json = Data(base64Encoded: content, options: .ignoreUnknownCharacters)
        else { throw .invalidContent }
        return RemoteSnapshot(data: try trainingData(fromJSON: json), revision: sha)
    }

    /// Un `db.json` leído del remoto; cualquier fallo, `invalidContent`.
    public static func trainingData(fromJSON json: Data) throws(RemoteError) -> TrainingData {
        do {
            return try PWAFormat.trainingData(from: json)
        } catch {
            throw .invalidContent
        }
    }
}

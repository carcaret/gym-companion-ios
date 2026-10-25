import Foundation

/// Cuerpo del `PUT /repos/{repo}/contents/{path}` de la API de GitHub.
public struct GitHubPutBody: Encodable, Hashable, Sendable {
    public var message: String
    /// El fichero en base64.
    public var content: String
    public var branch: String
    /// La versión que se sustituye; sin ella, GitHub crea el fichero.
    public var sha: String?
}

/// Un fichero leído con `GET /repos/{repo}/contents/{path}`.
public struct GitHubFile: Hashable, Sendable {
    /// El contenido ya decodificado.
    public var content: Data
    public var sha: String?

    public var json: JSONValue? { JSONValue(parsing: content) }
}

/// El formato de la API de contenidos de GitHub (`src/github.js` de la PWA).
public enum GitHubContents {
    /// `buildGitHubPayload`: el `db` como lo escribe la PWA (`JSON.stringify(db, null, 2)`), en
    /// base64 de su UTF-8.
    public static func payload(for db: JSONValue, sha: String?, branch: String = "main", message: String = "") -> GitHubPutBody {
        payload(for: Data(db.stringified().utf8), sha: sha, branch: branch, message: message)
    }

    static func payload(for content: Data, sha: String?, branch: String, message: String) -> GitHubPutBody {
        GitHubPutBody(message: message.isEmpty ? "Gym Companion update" : message, content: content.base64EncodedString(), branch: branch, sha: sha)
    }

    /// `parseGitHubResponse`: `nil` si la respuesta no trae el contenido en base64 con JSON válido.
    public static func parse(_ response: Data) -> GitHubFile? {
        struct Response: Decodable {
            var content: String?
            var sha: String?
            var encoding: String?
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: response),
              let content = response.content,
              response.encoding == nil || response.encoding == "base64",
              let data = Data(base64Encoded: content.replacingOccurrences(of: "\n", with: "")),
              JSONValue(parsing: data) != nil
        else { return nil }
        return GitHubFile(content: data, sha: response.sha)
    }
}

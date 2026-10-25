import Adapters
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Imita la API de contenidos de GitHub con los ficheros en memoria: GET da el fichero en base64
/// (en líneas de 60, como GitHub) con su `sha`; PUT lo crea o sustituye si el `sha` es el actual,
/// y si no, da 409 (o 422 si falta). Guarda las peticiones para comprobarlas.
actor FakeGitHubServer: HTTPTransport {
    private var files: [String: (content: Data, sha: String)] = [:]
    private var counter = 0
    private(set) var requests: [URLRequest] = []

    func store(_ content: Data, at path: String) {
        counter += 1
        files[path] = (content, "sha\(counter)")
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard let url = request.url, let range = url.path.range(of: "/contents/") else { return (Data(), 404) }
        let path = String(url.path[range.upperBound...])
        switch request.httpMethod ?? "GET" {
        case "GET":
            guard let file = files[path] else { return (Data(#"{"message":"Not Found"}"#.utf8), 404) }
            let base64 = file.content.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            let body: JSONValue = ["content": .string(base64), "sha": .string(file.sha), "encoding": "base64"]
            return (Data(body.stringified().utf8), 200)
        case "PUT":
            guard let body = request.httpBody.flatMap({ JSONValue(parsing: $0) }), case .string(let content)? = body["content"],
                  let data = Data(base64Encoded: content)
            else { return (Data(), 400) }
            var sha: String?
            if case .string(let given)? = body["sha"] { sha = given }
            switch (files[path], sha) {
            case (nil, nil): break
            case (let existing?, let given?) where existing.sha == given: break
            case (_?, nil): return (Data(#"{"message":"sha wasn't supplied"}"#.utf8), 422)
            default: return (Data(#"{"message":"conflict"}"#.utf8), 409)
            }
            store(data, at: path)
            let response: JSONValue = ["content": ["sha": .string(files[path]!.sha)]]
            return (Data(response.stringified().utf8), 200)
        default:
            return (Data(), 405)
        }
    }
}

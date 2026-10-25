import Adapters
import Application
import Domain
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import GymCoreTesting
import Testing

// Portados de tests/unit/github.test.js (buildGitHubPayload, parseGitHubResponse) y
// json-parse-safety.test.js de la PWA, más el adaptador entero contra un transporte falso.

private func base64(_ json: String) -> String { Data(json.utf8).base64EncodedString() }

private func jsonObject(_ data: Data) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@Suite("buildGitHubPayload")
struct PayloadTests {
    private let sample = TrainingData(catalog: Catalog([]), routines: [], history: [])

    @Test("genera JSON con content en base64")
    func base64Content() throws {
        let payload = try jsonObject(GitHubContents.payload(for: sample, sha: nil, branch: "master", message: "m"))
        let content = try #require(payload["content"] as? String)
        #expect(try PWAFormat.trainingData(from: try #require(Data(base64Encoded: content))) == sample)
    }

    @Test("incluye sha si se proporciona (update)")
    func sha() throws {
        #expect(try jsonObject(GitHubContents.payload(for: sample, sha: "abc123sha", branch: "master", message: "m"))["sha"] as? String == "abc123sha")
    }

    @Test("sin sha → no incluye campo sha (create)")
    func noSha() throws {
        #expect(try jsonObject(GitHubContents.payload(for: sample, sha: nil, branch: "master", message: "m"))["sha"] == nil)
    }

    @Test("incluye message y branch")
    func messageAndBranch() throws {
        let payload = try jsonObject(GitHubContents.payload(for: sample, sha: nil, branch: "dev", message: "test commit"))
        #expect(payload["message"] as? String == "test commit")
        #expect(payload["branch"] as? String == "dev")
    }

    @Test("DB con caracteres UTF-8 (tildes, eñes) → se codifica correctamente")
    func utf8() throws {
        let data = TrainingData(catalog: Catalog([Exercise(id: "curl", name: "Curl de bíceps con mancuerna — España")]))
        let content = try #require(try jsonObject(GitHubContents.payload(for: data, sha: nil, branch: "master", message: "m"))["content"] as? String)
        #expect(try PWAFormat.trainingData(from: try #require(Data(base64Encoded: content))).catalog["curl"]?.name == "Curl de bíceps con mancuerna — España")
    }
}

@Suite("parseGitHubResponse")
struct ParseResponseTests {
    private let sampleJSON = #"{"exercises": {}, "history": []}"#

    private func response(_ fields: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: fields)
    }

    @Test("extrae content (base64) y sha del response")
    func extracts() throws {
        let snapshot = try GitHubContents.snapshot(from: response(["content": base64(sampleJSON), "sha": "sha123", "encoding": "base64"]))
        #expect(snapshot.data == TrainingData(routines: Routine.defaults))
        #expect(snapshot.revision == "sha123")
    }

    @Test("content con line breaks en base64 → limpia y decodifica")
    func lineBreaks() throws {
        let raw = base64(sampleJSON)
        let withBreaks = stride(from: 0, to: raw.count, by: 40).map { start in
            String(raw.dropFirst(start).prefix(40))
        }.joined(separator: "\n")
        #expect(try GitHubContents.snapshot(from: response(["content": withBreaks, "sha": "sha456", "encoding": "base64"])).revision == "sha456")
    }

    @Test("response sin content → null")
    func noContent() throws {
        #expect(throws: RemoteError.invalidContent) { try GitHubContents.snapshot(from: response([:])) }
        #expect(throws: RemoteError.invalidContent) { try GitHubContents.snapshot(from: response(["sha": "abc"])) }
    }

    @Test("response con encoding !== base64 → null")
    func otherEncoding() throws {
        #expect(throws: RemoteError.invalidContent) { try GitHubContents.snapshot(from: response(["content": "some content", "sha": "abc", "encoding": "utf-8"])) }
    }

    @Test("response null → null")
    func null() {
        #expect(throws: RemoteError.invalidContent) { try GitHubContents.snapshot(from: Data("null".utf8)) }
    }

    @Test("content con UTF-8 (tildes, eñes) → decodifica correctamente")
    func utf8() throws {
        let json = #"{"exercises": {"a": {"id": "a", "name": "Sentadilla búlgara — España"}}, "history": []}"#
        let snapshot = try GitHubContents.snapshot(from: response(["content": base64(json), "sha": "sha789", "encoding": "base64"]))
        #expect(snapshot.data.catalog["a"]?.name == "Sentadilla búlgara — España")
    }

    @Test("sin campo encoding pero con content válido → funciona (encoding es opcional)")
    func noEncoding() throws {
        #expect(try GitHubContents.snapshot(from: response(["content": base64(sampleJSON), "sha": "sha000"])).revision == "sha000")
    }

    @Test("sin sha no hay revisión con la que subir encima")
    func noSha() throws {
        #expect(throws: RemoteError.invalidContent) { try GitHubContents.snapshot(from: response(["content": base64(sampleJSON)])) }
    }
}

/// En la PWA, `safeParse` protegía la lectura de localStorage y del remoto; aquí, que un `db.json`
/// remoto dañado se convierta en `RemoteError.invalidContent` sin romper nada.
@Suite("safe JSON.parse pattern")
struct RemoteContentSafetyTests {
    private func parse(_ text: String) throws(RemoteError) -> TrainingData {
        try GitHubContents.trainingData(fromJSON: Data(text.utf8))
    }

    @Test("JSON válido → devuelve objeto")
    func valid() throws { #expect(try parse(#"{"exercises": {}, "history": []}"#).history.isEmpty) }

    @Test("JSON inválido → devuelve null sin excepción")
    func invalid() { #expect(throws: RemoteError.invalidContent) { try parse("{corrupto}") } }

    @Test("string vacío → devuelve null")
    func empty() { #expect(throws: RemoteError.invalidContent) { try parse("") } }

    @Test("null → devuelve null")
    func null() { #expect(throws: RemoteError.invalidContent) { try parse("null") } }

    @Test("HTML como valor → no lanza excepción")
    func html() { #expect(throws: RemoteError.invalidContent) { try parse("<html>") } }

    @Test("JSON truncado → no lanza excepción")
    func truncated() { #expect(throws: RemoteError.invalidContent) { try parse(#"{"auth":{"user":"carlos""#) } }
}

/// Transporte falso: responde lo que se le diga y apunta las peticiones.
private final class FakeHTTP: HTTPTransport, @unchecked Sendable {
    var responses: [(status: Int, body: Data)] = []
    var failure: URLError?
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if let failure { throw failure }
        let next = responses.removeFirst()
        return (next.body, next.status)
    }
}

@Suite("Remoto de GitHub")
struct GitHubRemoteTests {
    private let settings = GitHubSettings(repository: "carcaret/gym-companion", branch: "master", path: "db.json")

    private func contents(_ data: TrainingData, sha: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["content": PWAFormat.json(from: data).base64EncodedString(), "sha": sha, "encoding": "base64"])
    }

    @Test("lee el fichero de la rama con el token")
    func fetches() async throws {
        let http = FakeHTTP()
        http.responses = [(200, try contents(TrainingDataStoreContract.sample, sha: "s1"))]
        let snapshot = try await GitHubRemote(settings: settings, token: "ghp_x", http: http).fetch()
        #expect(snapshot.revision == "s1")
        #expect(snapshot.data.history == TrainingDataStoreContract.sample.history)
        let request = try #require(http.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://api.github.com/repos/carcaret/gym-companion/contents/db.json?ref=master")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ghp_x")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github.v3+json")
    }

    @Test("sin token también lee (el repo es público), pero sin cabecera de autorización")
    func fetchesWithoutToken() async throws {
        let http = FakeHTTP()
        http.responses = [(200, try contents(TrainingData(), sha: "s1"))]
        _ = try await GitHubRemote(settings: settings, token: nil, http: http).fetch()
        #expect(http.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("sube con PUT encima de la revisión y devuelve la nueva")
    func pushes() async throws {
        let http = FakeHTTP()
        http.responses = [(200, Data(#"{"content": {"sha": "s2"}}"#.utf8))]
        let revision = try await GitHubRemote(settings: settings, token: "ghp_x", http: http).push(TrainingData(), over: "s1", message: "Gym Companion update 2026-10-25")
        #expect(revision == "s2")
        let request = try #require(http.requests.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.absoluteString == "https://api.github.com/repos/carcaret/gym-companion/contents/db.json")
        let body = try jsonObject(try #require(request.httpBody))
        #expect(body["sha"] as? String == "s1")
        #expect(body["branch"] as? String == "master")
        #expect(body["message"] as? String == "Gym Companion update 2026-10-25")
    }

    @Test("sin token no se puede subir")
    func pushWithoutToken() async {
        let http = FakeHTTP()
        await #expect(throws: RemoteError.unauthorized) { try await GitHubRemote(settings: settings, token: nil, http: http).push(TrainingData(), over: "s1", message: "m") }
        #expect(http.requests.isEmpty)
    }

    @Test("traduce los errores HTTP", arguments: [
        (401, RemoteError.unauthorized), (403, .unauthorized), (404, .notFound), (409, .conflict), (422, .conflict), (500, .http(500)),
    ])
    func httpErrors(status: Int, error: RemoteError) async {
        let http = FakeHTTP()
        http.responses = [(status, Data("{}".utf8)), (status, Data("{}".utf8))]
        let remote = GitHubRemote(settings: settings, token: "ghp_x", http: http)
        await #expect(throws: error) { try await remote.push(TrainingData(), over: "s1", message: "m") }
        if error != .conflict { await #expect(throws: error) { try await remote.fetch() } }
    }

    @Test("sin red → unavailable")
    func offline() async {
        let http = FakeHTTP()
        http.failure = URLError(.notConnectedToInternet)
        await #expect(throws: RemoteError.unavailable) { try await GitHubRemote(settings: settings, token: "ghp_x", http: http).fetch() }
    }
}

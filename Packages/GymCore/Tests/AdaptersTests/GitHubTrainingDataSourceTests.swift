import Adapters
import Application
import Domain
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import GymCoreTesting
import Testing

@Suite("Adaptador de GitHub (API de contenidos)")
struct GitHubTrainingDataSourceTests {
    private let location = SyncLocation(repository: "u/r", branch: "main", path: "datos/db.json")

    @Test(arguments: RemoteTrainingDataSourceContract.allCases)
    func contract(_ check: RemoteTrainingDataSourceContract) async throws {
        try await check.verify(makeSource: {
            (GitHubTrainingDataSource(transport: FakeGitHubServer()), SyncLocation(repository: "u/r", branch: "main", path: "db.json"), "ghp_test")
        })
    }

    @Test("GET a la API de contenidos con la rama, el token y la cabecera de la v3")
    func getRequest() async throws {
        let server = FakeGitHubServer()
        await server.store(PWAFormat.json(from: TrainingData()), at: "datos/db.json")
        _ = try await GitHubTrainingDataSource(transport: server).fetch(location, token: "ghp_secreto")
        let request = try #require(await server.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://api.github.com/repos/u/r/contents/datos/db.json?ref=main")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ghp_secreto")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github.v3+json")
    }

    @Test("PUT con el db.json de la PWA en base64, la rama, el mensaje y el sha")
    func putRequest() async throws {
        let server = FakeGitHubServer()
        let version = try await GitHubTrainingDataSource(transport: server)
            .push(TrainingDataStoreContract.sample, to: location, token: "ghp_secreto", replacing: nil, on: LocalDate(year: 2026, month: 10, day: 25)!)
        let request = try #require(await server.requests.last)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.absoluteString == "https://api.github.com/repos/u/r/contents/datos/db.json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ghp_secreto")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let httpBody = try #require(request.httpBody)
        let body = try #require(JSONValue(parsing: httpBody))
        #expect(body["branch"] == "main")
        #expect(body["message"] == "Gym Companion update 2026-10-25")
        #expect(body["sha"] == nil)
        guard case .string(let content)? = body["content"] else { Issue.record("sin content"); return }
        #expect(Data(base64Encoded: content) == PWAFormat.json(from: TrainingDataStoreContract.sample))

        _ = try await GitHubTrainingDataSource(transport: server)
            .push(TrainingData(), to: location, token: "ghp_secreto", replacing: version, on: LocalDate(year: 2026, month: 10, day: 25)!)
        let secondBody = try #require(await server.requests.last?.httpBody)
        let second = try #require(JSONValue(parsing: secondBody))
        #expect(second["sha"] == .string(version.rawValue))
    }

    @Test("códigos de error: 409 y 422 son conflicto; los demás, su código")
    func statuses() async throws {
        let source = { (status: Int) in GitHubTrainingDataSource(transport: CannedTransport(status: status, body: #"{"message":"x"}"#)) }
        for status in [409, 422] {
            await #expect(throws: RemoteError.conflict) {
                try await source(status).push(TrainingData(), to: location, token: "t", replacing: nil, on: LocalDate(year: 2026, month: 10, day: 25)!)
            }
        }
        await #expect(throws: RemoteError.unauthorized) { try await source(401).fetch(location, token: "t") }
        await #expect(throws: RemoteError.unauthorized) { try await source(403).fetch(location, token: "t") }
        await #expect(throws: RemoteError.notFound) { try await source(404).fetch(location, token: "t") }
        await #expect(throws: RemoteError.failed(status: 500)) {
            try await source(500).push(TrainingData(), to: location, token: "t", replacing: nil, on: LocalDate(year: 2026, month: 10, day: 25)!)
        }
    }

    @Test("sin red, inaccesible")
    func unreachable() async {
        let source = GitHubTrainingDataSource(transport: CannedTransport(failure: URLError(.notConnectedToInternet)))
        await #expect(throws: RemoteError.unreachable) { try await source.fetch(location, token: "t") }
        await #expect(throws: RemoteError.unreachable) {
            try await source.push(TrainingData(), to: location, token: "t", replacing: nil, on: LocalDate(year: 2026, month: 10, day: 25)!)
        }
    }

    @Test("un contenido que no es un db.json válido no se aplica")
    func invalidContent() async {
        let corrupt = Data("{corrupto".utf8).base64EncodedString()
        let noHistory = Data(#"{"exercises": {}}"#.utf8).base64EncodedString()
        for content in [corrupt, noHistory] {
            let source = GitHubTrainingDataSource(transport: CannedTransport(status: 200, body: #"{"content": "\#(content)", "sha": "s", "encoding": "base64"}"#))
            await #expect(throws: RemoteError.invalidContent) { try await source.fetch(location, token: "t") }
        }
        let html = GitHubTrainingDataSource(transport: CannedTransport(status: 200, body: "<html>"))
        await #expect(throws: RemoteError.invalidContent) { try await html.fetch(location, token: "t") }
    }
}

/// Respuesta fija, o un fallo de red.
private struct CannedTransport: HTTPTransport {
    var status = 200
    var body = ""
    var failure: URLError?

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        if let failure { throw failure }
        return (Data(body.utf8), status)
    }
}

import Adapters
import Application
import Domain
import Foundation
import GymCoreTesting
import Testing

@Suite("El salud.json en GitHub (API de contenidos)")
struct GitHubHealthRecordStoreTests {
    private let location = SyncLocation(repository: "u/gym-data", branch: "master", path: "salud.json")

    @Test(arguments: RemoteHealthRecordStoreContract.allCases)
    func contract(_ check: RemoteHealthRecordStoreContract) async throws {
        try await check.verify(makeStore: { (GitHubHealthRecordStore(transport: FakeGitHubServer()), location, "ghp_test") })
    }

    @Test("PUT del salud.json en base64, en su rama y con su mensaje")
    func putRequest() async throws {
        let server = FakeGitHubServer()
        _ = try await GitHubHealthRecordStore(transport: server)
            .push(HealthFixtures.record, to: location, token: "ghp_secreto", replacing: nil, on: LocalDate(year: 2026, month: 11, day: 1)!)
        let request = try #require(await server.requests.last)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.absoluteString == "https://api.github.com/repos/u/gym-data/contents/salud.json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer ghp_secreto")
        let body = try #require(request.httpBody.flatMap { JSONValue(parsing: $0) })
        #expect(body["message"] == "Salud update 2026-11-01")
        #expect(body["branch"] == "master")
        guard case .string(let content)? = body["content"] else { Issue.record("Sin contenido"); return }
        #expect(Data(base64Encoded: content) == HealthRecordFormat.json(from: HealthFixtures.record))
    }

    @Test("un fichero que no es un salud.json no se lee")
    func invalidContent() async {
        let server = FakeGitHubServer()
        await server.store(Data(#"{"otra":"cosa"}"#.utf8), at: "salud.json")
        await #expect(throws: RemoteError.invalidContent) {
            try await GitHubHealthRecordStore(transport: server).fetch(location, token: "t")
        }
    }
}

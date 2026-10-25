import Adapters
import Foundation
import Testing

// Port de tests/unit/github.test.js: el cuerpo del PUT y la lectura del GET de la API de
// contenidos de GitHub. La PWA recibe y devuelve objetos; aquí el `db` es un `JSONValue`.

private func decodeBase64(_ content: String) throws -> JSONValue {
    let data = try #require(Data(base64Encoded: content))
    return try #require(JSONValue(parsing: data))
}

@Suite("buildGitHubPayload")
struct BuildGitHubPayloadTests {
    let sampleDb: JSONValue = ["exercises": [:], "routines": [:], "history": []]

    @Test("genera JSON con content en base64")
    func base64() throws {
        let payload = GitHubContents.payload(for: sampleDb, sha: nil)
        #expect(!payload.content.isEmpty)
        #expect(try decodeBase64(payload.content) == sampleDb)
    }

    @Test("incluye sha si se proporciona (update)")
    func withSha() {
        #expect(GitHubContents.payload(for: sampleDb, sha: "abc123sha").sha == "abc123sha")
    }

    @Test("sin sha → no incluye campo sha (create)")
    func withoutSha() throws {
        let payload = GitHubContents.payload(for: sampleDb, sha: nil)
        let body = try #require(JSONValue(parsing: JSONEncoder().encode(payload)))
        #expect(body["sha"] == nil)
        #expect(body["content"] != nil)
    }

    @Test("incluye message y branch")
    func messageAndBranch() {
        let payload = GitHubContents.payload(for: sampleDb, sha: nil, branch: "dev", message: "test commit")
        #expect(payload.message == "test commit")
        #expect(payload.branch == "dev")
    }

    @Test("DB con caracteres UTF-8 (tildes, eñes) → se codifica correctamente")
    func utf8() throws {
        let dbUtf8: JSONValue = ["exercises": ["curl": ["id": "curl", "name": "Curl de bíceps con mancuerna — España"]]]
        let payload = GitHubContents.payload(for: dbUtf8, sha: nil)
        #expect(try decodeBase64(payload.content)["exercises"]?["curl"]?["name"] == "Curl de bíceps con mancuerna — España")
    }
}

@Suite("parseGitHubResponse")
struct ParseGitHubResponseTests {
    private func encodeDbToBase64(_ db: JSONValue) -> String {
        Data(db.stringified().utf8).base64EncodedString()
    }

    private func response(_ body: JSONValue) -> Data {
        Data(body.stringified().utf8)
    }

    let sampleDb: JSONValue = ["exercises": [:], "history": []]

    @Test("extrae content (base64) y sha del response")
    func extracts() throws {
        let file = try #require(GitHubContents.parse(response(["content": .string(encodeDbToBase64(sampleDb)), "sha": "sha123", "encoding": "base64"])))
        #expect(file.json == sampleDb)
        #expect(file.sha == "sha123")
    }

    @Test("content con line breaks en base64 → limpia y decodifica")
    func lineBreaks() throws {
        let raw = encodeDbToBase64(sampleDb)
        var withBreaks = ""
        for (index, character) in raw.enumerated() {
            if index > 0, index.isMultiple(of: 40) { withBreaks.append("\n") }
            withBreaks.append(character)
        }
        let file = try #require(GitHubContents.parse(response(["content": .string(withBreaks), "sha": "sha456", "encoding": "base64"])))
        #expect(file.json == sampleDb)
    }

    @Test("response sin content → null")
    func noContent() {
        #expect(GitHubContents.parse(response([:])) == nil)
        #expect(GitHubContents.parse(response(["sha": "abc"])) == nil)
    }

    @Test("response con encoding !== base64 → null")
    func otherEncoding() {
        #expect(GitHubContents.parse(response(["content": "some content", "sha": "abc", "encoding": "utf-8"])) == nil)
    }

    @Test("response null → null")
    func null() {
        #expect(GitHubContents.parse(Data("null".utf8)) == nil)
    }

    @Test("content con UTF-8 (tildes, eñes) → decodifica correctamente")
    func utf8() throws {
        let dbUtf8: JSONValue = ["name": "Sentadilla búlgara — España", "exercises": [:]]
        let file = try #require(GitHubContents.parse(response(["content": .string(encodeDbToBase64(dbUtf8)), "sha": "sha789", "encoding": "base64"])))
        #expect(file.json?["name"] == "Sentadilla búlgara — España")
    }

    @Test("sin campo encoding pero con content válido → funciona (encoding es opcional)")
    func optionalEncoding() throws {
        let file = try #require(GitHubContents.parse(response(["content": .string(encodeDbToBase64(sampleDb)), "sha": "sha000"])))
        #expect(file.json == sampleDb)
    }
}

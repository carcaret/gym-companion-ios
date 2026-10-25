#if canImport(Security)
import Adapters
import Foundation
import Testing

/// Solo en plataformas de Apple (en el CI, el job de macOS).
@Suite("Token en el Llavero")
struct KeychainCredentialStoreTests {
    private let store = KeychainCredentialStore(service: "com.carcaret.gymcompanion.tests.\(UUID().uuidString)")

    @Test("guarda, lee, sustituye y borra el token")
    func lifecycle() async throws {
        #expect(try await store.token() == nil)
        try await store.setToken("ghp_uno")
        #expect(try await store.token() == "ghp_uno")
        try await store.setToken("ghp_dos")
        #expect(try await store.token() == "ghp_dos")
        try await store.setToken(nil)
        #expect(try await store.token() == nil)
    }
}
#endif

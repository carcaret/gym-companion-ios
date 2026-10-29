#if canImport(Security)
import AppleAdapters
import Application
import Foundation
import GymCoreTesting
import Testing

// Solo en Apple (el job `watch` del CI, que pasa el paquete en macOS); en Linux no hay Llavero.
@Suite("Token en el Llavero", .serialized)
struct KeychainCredentialStoreTests {
    @Test(arguments: CredentialStoreContract.allCases)
    func contract(_ check: CredentialStoreContract) async throws {
        let service = "com.carcaret.gymcompanion.tests.\(UUID().uuidString)"
        defer { try? KeychainCredentialStore(service: service).deleteToken() }
        try await check.verify(makeStores: {
            { KeychainCredentialStore(service: service) }
        })
    }
}
#endif

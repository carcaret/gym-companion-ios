import Adapters
import Application
import Foundation
import GymCoreTesting
import Testing

@Suite("Configuración de la sincronización en fichero JSON")
struct JSONFileSyncSettingsStoreTests {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).appendingPathComponent("sync.json")
    }

    @Test(arguments: SyncSettingsStoreContract.allCases)
    func contract(_ check: SyncSettingsStoreContract) async throws {
        try await check.verify(makeStores: {
            let file = temporaryFile()
            return { JSONFileSyncSettingsStore(file: file) }
        })
    }

    @Test("el token no se guarda en el fichero")
    func noToken() async throws {
        let file = temporaryFile()
        try await JSONFileSyncSettingsStore(file: file).save(SyncSettings(location: SyncLocation(repository: "u/r"), hasPendingUpload: true))
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("u/r"))
        #expect(!text.lowercased().contains("token"))
    }

    @Test("un fichero corrupto da error, no una configuración vacía")
    func corrupt() async throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ no".utf8).write(to: file)
        await #expect(throws: (any Error).self) { try await JSONFileSyncSettingsStore(file: file).load() }
    }
}

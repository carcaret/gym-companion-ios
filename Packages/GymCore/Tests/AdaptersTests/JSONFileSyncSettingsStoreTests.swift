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

    // El formato es del adaptador, no de SyncLocation: renombrar un campo del modelo no puede romper
    // el fichero que ya tiene el iPhone (repaso del 2026-10-29).
    @Test("lee el sync.json que ya hay en el iPhone")
    func existingFormat() async throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"hasPendingUpload":true,"location":{"branch":"main","path":"datos/db.json","repository":"u/r"}}"#.utf8).write(to: file)
        let settings = try await JSONFileSyncSettingsStore(file: file).load()
        #expect(settings == SyncSettings(location: SyncLocation(repository: "u/r", branch: "main", path: "datos/db.json"), hasPendingUpload: true))
    }

    @Test("un fichero corrupto da error, no una configuración vacía")
    func corrupt() async throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ no".utf8).write(to: file)
        await #expect(throws: (any Error).self) { try await JSONFileSyncSettingsStore(file: file).load() }
    }
}

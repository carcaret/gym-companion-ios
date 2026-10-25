import Adapters
import Application
import Foundation
import Testing

@Suite("Metadatos de sincronización en fichero")
struct JSONFileSyncMetadataStoreTests {
    private func file() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("sync.json")
    }

    @Test("sin fichero, nada pendiente ni revisión")
    func empty() async throws {
        #expect(try await JSONFileSyncMetadataStore(file: file()).load() == SyncMetadata())
    }

    @Test("lo guardado lo ve el siguiente arranque")
    func survives() async throws {
        let url = file()
        try await JSONFileSyncMetadataStore(file: url).save(SyncMetadata(needsUpload: true, revision: "abc"))
        #expect(try await JSONFileSyncMetadataStore(file: url).load() == SyncMetadata(needsUpload: true, revision: "abc"))
    }
}

@Suite("Ajustes de GitHub en las preferencias")
struct UserDefaultsGitHubSettingsStoreTests {
    private func defaults() -> UserDefaults {
        let name = "tests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test("sin ajustes, sin configurar")
    func empty() async {
        #expect(await UserDefaultsGitHubSettingsStore(defaults: defaults()).load() == nil)
    }

    @Test("guarda y lee repo, rama y ruta; nil los borra")
    func roundTrip() async {
        let store = UserDefaultsGitHubSettingsStore(defaults: defaults())
        await store.save(GitHubSettings(repository: "u/r", branch: "dev", path: "datos/db.json"))
        #expect(await store.load() == GitHubSettings(repository: "u/r", branch: "dev", path: "datos/db.json"))
        await store.save(nil)
        #expect(await store.load() == nil)
    }
}

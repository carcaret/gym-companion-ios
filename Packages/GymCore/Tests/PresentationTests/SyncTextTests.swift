import Presentation
import Testing

@Suite("Textos de la sincronización")
struct SyncTextTests {
    @Test("los errores de conexión dicen el código y qué revisar")
    func connectionError() {
        #expect(SyncText.connectionError(status: 401) == Notice("Error 401 — verifica repo, PAT y rama", .error))
    }

    @Test("los fallos se avisan como error y los éxitos como éxito")
    func kinds() {
        #expect(SyncText.uploadFailed.kind == .error)
        #expect(SyncText.downloadFailed.kind == .error)
        #expect(SyncText.offline.kind == .error)
        #expect(SyncText.configureFailed.kind == .error)
        #expect(SyncText.uploaded.kind == .success)
        #expect(SyncText.remoteApplied.kind == .success)
        #expect(SyncText.notConfigured.kind == .warning)
    }
}

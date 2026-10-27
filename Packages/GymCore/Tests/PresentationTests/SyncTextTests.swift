import Presentation
import Testing

@Suite("Textos de la sincronización")
struct SyncTextTests {
    @Test("los errores de conexión dicen el código y qué revisar")
    func connectionError() {
        #expect(SyncText.connectionError(status: 401) == Notice("Error 401 — verifica repo, PAT y rama", .error))
    }

    // Antes «Subir local → GitHub», «Bajar GitHub → local» y «db.json» en el mensaje, como el
    // `confirm()` de la PWA (2026-10-27).
    @Test("el conflicto y la descarga dicen qué datos se quedan, sin flechas ni nombres de fichero")
    func choices() {
        #expect(SyncText.keepLocalLabel == "Usar los de este iPhone")
        #expect(SyncText.keepRemoteLabel == "Usar los de GitHub")
        #expect(!SyncText.conflictMessage.contains("db.json"))
        #expect(SyncText.downloadConfirm == "Sustituir")
        #expect(!SyncText.downloadWarning.contains("¿Continuar?"))
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

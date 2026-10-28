import Presentation
import Testing

@Suite("Textos de la sincronización")
struct SyncTextTests {
    // Antes «Error 401 — verifica repo, PAT y rama»: sin código ni jerga, con los nombres de los
    // campos de los ajustes y qué hacer (repaso de la HIG, 2026-10-28).
    @Test("los errores de conexión dicen qué pasa y qué revisar, sin código ni jerga")
    func connectionError() {
        let token = Notice("GitHub no acepta el token de acceso. Revisa el token, el repositorio y la rama.", .error)
        #expect(SyncText.connectionError(status: 401) == token)
        #expect(SyncText.connectionError(status: 403) == token)
        #expect(SyncText.connectionError(status: 404) == Notice("GitHub no encuentra el repositorio, la rama o la ruta. Revísalos.", .error))
        #expect(SyncText.connectionError(status: 500) == Notice("GitHub ha respondido con un error. Prueba otra vez más tarde.", .error))
        for status in [401, 403, 404, 500] {
            let text = SyncText.connectionError(status: status).text
            #expect(!text.contains("\(status)") && !text.contains("PAT") && !text.contains("repo,"), "\(text)")
        }
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

    @Test("en el menú de la nube, lo que abre otra pantalla lleva «…»")
    func ellipsis() {
        #expect(SyncText.configureLabel.hasSuffix("…"))
        #expect(SyncText.resolveConflictLabel.hasSuffix("…"))
        #expect(SyncText.settingsLabel.hasSuffix("…"))
        #expect(!SyncText.syncNowLabel.hasSuffix("…"))
    }
}

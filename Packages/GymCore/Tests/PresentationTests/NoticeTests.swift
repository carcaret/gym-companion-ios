import Presentation
import Testing

/// Lo que se va solo se pierde si no se mira a tiempo: los errores esperan a que se cierren y lo
/// demás se va solo (repaso de la HIG, 2026-10-28; antes, todo a los 2,5 s).
@Suite("Avisos")
struct NoticeTests {
    @Test("un error se queda hasta que se cierra")
    func errorStays() {
        #expect(SyncText.offline.staysUntilDismissed)
        #expect(SyncText.uploadFailed.staysUntilDismissed)
        #expect(Notice("x", .error).staysUntilDismissed)
    }

    @Test("lo demás se va solo")
    func othersExpire() {
        #expect(!SyncText.synced.staysUntilDismissed)
        #expect(!SyncText.notConfigured.staysUntilDismissed)
        #expect(!SyncText.waitingForWorkout.staysUntilDismissed)
    }
}

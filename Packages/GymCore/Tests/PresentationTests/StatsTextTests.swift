import Presentation
import Testing

@Suite("Textos de Progreso")
struct StatsTextTests {
    /// En iOS, cada etiqueta suelta empieza en mayúscula (repaso de la HIG, 2026-10-28; la PWA las
    /// ponía en minúscula).
    @Test("las leyendas empiezan en mayúscula")
    func legends() {
        #expect(StatsText.direct == "Directo")
        #expect(StatsText.indirect == "Indirecto")
        #expect(StatsText.window(weeks: 8) == "Últimas 8 semanas")
    }
}

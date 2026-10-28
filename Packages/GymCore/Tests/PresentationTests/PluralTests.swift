import Presentation
import Testing

/// Los recuentos concuerdan con su número: antes salía «1 ejercicios», «0 ejercicios · » y
/// «1 de 1 estancados» (repaso de la HIG, 2026-10-28).
@Suite("Plurales")
struct PluralTests {
    @Test("una rutina con un ejercicio o sin ninguno")
    func routine() {
        #expect(TodayText.routineSummary(["Press Banca"]) == "1 ejercicio · Press Banca")
        #expect(TodayText.routineSummary([]) == "Sin ejercicios")
        #expect(TodayText.routineSummary(["A", "B"]) == "2 ejercicios · A, B")
    }

    @Test("una sesión con un ejercicio o sin ninguno")
    func session() {
        #expect(HistoryText.sessionSummary(["Press Banca"]) == "1 ejercicio · Press Banca")
        #expect(HistoryText.sessionSummary([]) == "Sin ejercicios")
    }

    /// Concuerda con el total: «1 de 3 estancados» es «uno de los tres estancados».
    @Test("con un solo ejercicio, «estancado»")
    func stalled() {
        #expect(StatsText.exercisesSubtitle(stalled: 1, total: 1, progressing: 0) == "1 de 1 estancado")
        #expect(StatsText.exercisesSubtitle(stalled: 1, total: 3, progressing: 0) == "1 de 3 estancados")
    }
}

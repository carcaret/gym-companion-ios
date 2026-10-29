import Domain
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
        #expect(ProgressText.exercisesSubtitle(stalled: 1, total: 1, progressing: 0) == "1 de 1 estancado")
        #expect(ProgressText.exercisesSubtitle(stalled: 1, total: 3, progressing: 0) == "1 de 3 estancados")
    }

    /// Lo vio la captura de Progreso del CI: «1 sesiones, aún sin recorrido».
    @Test("un ejercicio con una sola sesión")
    func oneSession() {
        #expect(ProgressText.phrase(ExerciseProgress(status: .noTrack, sessionCount: 1)) == "1 sesión, aún sin recorrido")
        #expect(ProgressText.phrase(ExerciseProgress(status: .noTrack, sessionCount: 2)) == "2 sesiones, aún sin recorrido")
    }

    @Test("un solo día")
    func oneDay() {
        #expect(ProgressText.span(days: 1) == "1 día")
        #expect(ProgressText.span(days: 9) == "9 días")
    }
}

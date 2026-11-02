import Domain
import Presentation
import Testing

// Portados de tests/unit/stats.test.js de la PWA (formatSpan, buildExercisePhrase y la frase de
// buildExerciseRows) y de los nombres de grupo de views/estadisticas.js.

@Suite("formatSpan")
struct SpanTests {
    @Test("menos de dos semanas, en días")
    func days() { #expect(ProgressText.span(days: 9) == "9 días") }

    @Test("menos de dos meses, en semanas")
    func weeks() { #expect(ProgressText.span(days: 21) == "3 semanas") }

    @Test("a partir de dos meses, en meses")
    func months() { #expect(ProgressText.span(days: 120) == "4 meses") }
}

@Suite("buildExercisePhrase")
struct PhraseTests {
    @Test("sin recorrido dice cuántas sesiones lleva")
    func noTrack() {
        #expect(ProgressText.phrase(ExerciseProgress(status: .noTrack, sessionCount: 2)) == "2 sesiones, aún sin recorrido")
    }

    @Test("progreso por peso")
    func weight() {
        #expect(ProgressText.phrase(ExerciseProgress(status: .progressing, weightFrom: 220, weightTo: 240, spanDays: 21)) == "220 → 240 kg en 3 semanas")
    }

    @Test("progreso por reps al mismo peso")
    func reps() {
        #expect(ProgressText.phrase(ExerciseProgress(status: .progressing, weightFrom: 68, weightTo: 68, repsFrom: 38, repsTo: 41)) == "38 → 41 reps al mismo peso")
    }

    @Test("estancado sin fallar reps")
    func stalledAllHit() {
        #expect(ProgressText.phrase(ExerciseProgress(status: .stalled, stallSessions: 6, bestReps: 27, allHit: true)) == "6 sesiones idénticas, ninguna rep fallada")
    }

    // «estancado con fallos usa el tiempo» de la PWA: ahora cuenta sesiones, porque tras un parón
    // «2 meses sin superar» eran dos sesiones (decisión del usuario, 2026-11-02;
    // docs/pwa-tests-no-aplican.tsv).
    @Test("estancado con fallos cuenta las sesiones que no superan el récord")
    func stalledMissed() {
        #expect(ProgressText.phrase(ExerciseProgress(status: .stalled, stallSessions: 5, bestReps: 40, allHit: false)) == "4 sesiones sin superar 40 reps")
        #expect(ProgressText.phrase(ExerciseProgress(status: .stalled, stallSessions: 2, bestReps: 44, allHit: false)) == "1 sesión sin superar 44 reps")
    }
}

@Suite("buildExerciseRows")
struct RowPhraseTests {
    @Test("cada fila trae su frase")
    func phrase() {
        let data = TrainingData(
            catalog: Catalog([Exercise(id: "a", name: "Aaa")]),
            history: ["2026-06-05", "2026-06-12", "2026-06-19"].map {
                Session(date: LocalDate($0), routineID: "DIA1", completed: true,
                        logs: [ExerciseLog(exerciseID: "a", series: 3, targetReps: 10, actualReps: [10], weight: 10)])
            }
        )
        let row = data.progressRows(for: ["a"], anchor: "2026-06-19", weeks: 8)[0]
        #expect(!ProgressText.phrase(row).isEmpty)
    }
}

@Suite("Nombres de grupo")
struct GroupNameTests {
    // «Sin grupo», sin los paréntesis de la PWA (cambiado con la aprobación del usuario,
    // 2026-10-27).
    @Test("con su ortografía, y «Sin grupo» sin paréntesis")
    func names() {
        #expect(GroupText.name(.biceps) == "Bíceps")
        #expect(GroupText.name(.triceps) == "Tríceps")
        #expect(GroupText.name(.pecho) == "Pecho")
        #expect(GroupText.name(.cuadriceps) == "Cuádriceps")
        #expect(GroupText.name(.femoralGluteo) == "Femoral y glúteo")
        #expect(GroupText.name(.gemelos) == "Gemelos")
        #expect(GroupText.name("brazos") == "Brazos")
        #expect(GroupText.name(nil) == "Sin grupo")
    }
}

@Suite("Textos de Progreso")
struct ProgressScreenTextTests {
    /// En iOS, cada etiqueta suelta empieza en mayúscula (repaso de la HIG, 2026-10-28; la PWA las
    /// ponía en minúscula).
    @Test("las leyendas empiezan en mayúscula")
    func legends() {
        #expect(ProgressText.direct == "Directo")
        #expect(ProgressText.indirect == "Indirecto")
        #expect(ProgressText.window(weeks: 8) == "Últimas 8 semanas")
    }
}

@Suite("Textos de las filas de Progreso")
struct ProgressRowTextTests {
    @Test("series y sesiones de un ejercicio del grupo")
    func setsAndSessions() {
        #expect(ProgressText.setsAndSessions(sets: 12, sessions: 4) == "12 · 4")
    }

    @Test("las series por semana de un grupo, con un decimal como mucho")
    func perWeek() {
        #expect(ProgressText.perWeek(12.75) == "12,8")
        #expect(ProgressText.perWeek(11) == "11")
        #expect(ProgressText.referenceBand(10...20) == "10–20 por semana")
    }

    @Test("el peso de la fila no repite el de la frase")
    func weight() {
        let weightUp = ExerciseProgress(weight: 15, status: .progressing, weightFrom: 14, weightTo: 15, spanDays: 21)
        #expect(ProgressText.phrase(weightUp) == "14 → 15 kg en 3 semanas")
        #expect(ProgressText.weight(weightUp) == nil)
        #expect(ProgressText.weight(ExerciseProgress(weight: 68, status: .progressing, weightFrom: 68, weightTo: 68)) == "68 kg")
        #expect(ProgressText.weight(ExerciseProgress(weight: 30, status: .stalled, weightFrom: 25, weightTo: 30)) == "30 kg")
        #expect(ProgressText.weight(ExerciseProgress(weight: 0, status: .stalled)) == nil)
    }
}

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

    @Test("estancado con fallos usa el tiempo")
    func stalledMissed() {
        #expect(ProgressText.phrase(ExerciseProgress(status: .stalled, stallSessions: 14, bestReps: 32, spanDays: 120, allHit: false)) == "4 meses sin superar 32 reps")
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
        #expect(GroupText.name("brazos") == "Brazos")
        #expect(GroupText.name(nil) == "Sin grupo")
    }
}

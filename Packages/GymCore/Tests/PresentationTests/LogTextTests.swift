import Domain
import Presentation
import Testing

// Las reps se separan con «·» y la serie vacía es «—» (cambiado con la aprobación del usuario,
// 2026-10-27; en la PWA, «10-8-10» y «10---8»).

// Portados de tests/unit/formatting.test.js de la PWA (formatRepsInteligente, formatLogSummary).

private func log(_ weight: Double, _ series: Int, _ expected: Int, _ actual: [Int?]) -> ExerciseLog {
    ExerciseLog(exerciseID: "x", series: series, targetReps: expected, actualReps: actual, weight: weight)
}

@Suite("formatRepsInteligente")
struct SmartRepsTests {
    @Test("todos iguales a expected -> null")
    func allMatch() { #expect(LogText.repsDetail([10, 10, 10], series: 3, target: 10) == nil) }

    @Test("algunos diferentes -> \"10-8-10\"")
    func different() { #expect(LogText.repsDetail([10, 8, 10], series: 3, target: 10) == "10·8·10") }

    @Test("con nulls -> \"-\" donde toque")
    func nulls() { #expect(LogText.repsDetail([10, nil, 8], series: 3, target: 10) == "10·—·8") }

    @Test("array vacio -> null")
    func empty() { #expect(LogText.repsDetail([], series: 3, target: 10) == nil) }

    @Test("null -> null")
    func allNull() {
        // En Swift la lista no puede ser `null`; lo equivalente es que no haya ninguna serie rellenada.
        #expect(LogText.repsDetail([nil, nil, nil], series: 3, target: 10) == nil)
    }

    @Test("menos reps completadas que series -> muestra lo que hay")
    func fewer() { #expect(LogText.repsDetail([10, 8], series: 3, target: 10) == "10·8") }
}

@Suite("Las reps de cada serie")
struct RepsTests {
    @Test("las reps de cada serie, separadas por un punto aunque se repitan")
    func reps() {
        #expect(LogText.reps([12, 12, 11, 10]) == "12·12·11·10")
        #expect(LogText.reps([12, 12, 12, 12]) == "12·12·12·12")
    }

    @Test("las series por las reps objetivo")
    func target() {
        #expect(LogText.target(series: 4, reps: 11) == "4×11")
    }

    @Test("una serie sin reps sale como una raya")
    func emptyRep() {
        #expect(LogText.reps([12, nil, 10]) == "12·—·10")
    }
}

@Suite("formatLogSummary")
struct LogSummaryTests {
    @Test("con peso → incluye \"X kg · \"")
    func withWeight() { #expect(LogText.summary(log(60, 3, 10, [10, 10, 10])) == "60 kg · 3×10") }

    @Test("sin peso (0) → omite \"kg\"")
    func noWeight() { #expect(LogText.summary(log(0, 3, 10, [10, 10, 10])) == "3×10") }

    @Test("con actual que difiere de expected → añade \"· X-X-X\"")
    func different() { #expect(LogText.summary(log(60, 3, 10, [10, 10, 8])) == "60 kg · 3×10 · 10·10·8") }

    @Test("con actual == expected en todas → omite reps reales")
    func allMatch() { #expect(LogText.summary(log(80, 4, 8, [8, 8, 8, 8])) == "80 kg · 4×8") }

    @Test("con reps actual null (no iniciadas) → solo muestra \"series×expected\"")
    func notStarted() { #expect(LogText.summary(log(60, 3, 10, [nil, nil, nil])) == "60 kg · 3×10") }

    @Test("array actual vacío → solo muestra \"series×expected\"")
    func empty() { #expect(LogText.summary(log(50, 3, 12, [])) == "50 kg · 3×12") }

    @Test("sin peso y con reps distintas → solo base + reps")
    func noWeightDifferent() { #expect(LogText.summary(log(0, 3, 10, [10, 8, 9])) == "3×10 · 10·8·9") }

    @Test("los decimales del peso van con coma")
    func decimalComma() {
        // La PWA escribía el número de JS ("52.5 kg"); en español, "52,5 kg".
        #expect(LogText.summary(log(52.5, 3, 10, [10, 10, 10])) == "52,5 kg · 3×10")
        #expect(LogText.kilograms(18.25) == "18,25")
        #expect(LogText.kilograms(100) == "100")
        #expect(LogText.kilograms(0.3) == "0,3")
        #expect(LogText.kilograms(-2.5) == "-2,5")
    }
}

@Suite("El peso con su unidad")
struct LogTextWeightTests {
    @Test("el peso con su unidad")
    func weight() {
        #expect(LogText.weight(60) == "60 kg")
        #expect(LogText.weight(52.5) == "52,5 kg")
    }
}

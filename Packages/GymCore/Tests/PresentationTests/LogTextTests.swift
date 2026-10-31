import Domain
import Presentation
import Testing

// Las reps se separan con «·» y la serie vacía es «—» (cambiado con la aprobación del usuario,
// 2026-10-27; en la PWA, «10-8-10» y «10---8»).

// Portados de tests/unit/formatting.test.js de la PWA (formatLogSummary). Los de
// formatRepsInteligente no aplican desde el 2026-10-31 (ver docs/pwa-tests-no-aplican.tsv).

private func log(_ weight: Double, _ series: Int, _ expected: Int, _ actual: [Int?]) -> ExerciseLog {
    ExerciseLog(exerciseID: "x", series: series, targetReps: expected, actualReps: actual, weight: weight)
}

@Suite("Las reps de cada serie")
struct RepsTests {
    @Test("las reps de cada serie, separadas por un punto aunque se repitan")
    func reps() {
        #expect(LogText.reps([12, 12, 11, 10]) == "12·12·11·10")
        #expect(LogText.reps([12, 12, 12, 12]) == "12·12·12·12")
    }

    @Test("una serie sin reps sale como una raya")
    func emptyRep() {
        #expect(LogText.reps([12, nil, 10]) == "12·—·10")
    }
}

// Cambiado con la aprobación del usuario (2026-10-31): sin «series×objetivo» y siempre con las
// reps de cada serie, como en el reloj. Cada test comprueba eso con el nombre del de la PWA.
@Suite("formatLogSummary")
struct LogSummaryTests {
    @Test("con peso → incluye \"X kg · \"")
    func withWeight() { #expect(LogText.summary(log(60, 3, 10, [10, 10, 10])) == "60 kg · 10·10·10") }

    @Test("sin peso (0) → omite \"kg\"")
    func noWeight() { #expect(LogText.summary(log(0, 3, 10, [10, 10, 10])) == "10·10·10") }

    @Test("con actual que difiere de expected → añade \"· X-X-X\"")
    func different() { #expect(LogText.summary(log(60, 3, 10, [10, 10, 8])) == "60 kg · 10·10·8") }

    @Test("con actual == expected en todas → omite reps reales")
    func allMatch() { #expect(LogText.summary(log(80, 4, 8, [8, 8, 8, 8])) == "80 kg · 8·8·8·8") }

    @Test("con reps actual null (no iniciadas) → solo muestra \"series×expected\"")
    func notStarted() { #expect(LogText.summary(log(60, 3, 10, [nil, nil, nil])) == "60 kg · —·—·—") }

    @Test("array actual vacío → solo muestra \"series×expected\"")
    func empty() { #expect(LogText.summary(log(50, 3, 12, [])) == "50 kg · —·—·—") }

    @Test("sin peso y con reps distintas → solo base + reps")
    func noWeightDifferent() { #expect(LogText.summary(log(0, 3, 10, [10, 8, 9])) == "10·8·9") }

    @Test("los decimales del peso van con coma")
    func decimalComma() {
        // La PWA escribía el número de JS ("52.5 kg"); en español, "52,5 kg".
        #expect(LogText.summary(log(52.5, 3, 10, [10, 10, 10])) == "52,5 kg · 10·10·10")
        #expect(LogText.kilograms(18.25) == "18,25")
        #expect(LogText.kilograms(100) == "100")
        #expect(LogText.kilograms(0.3) == "0,3")
        #expect(LogText.kilograms(-2.5) == "-2,5")
    }

    @Test("más reps apuntadas que series: solo las de las series")
    func moreRepsThanSeries() { #expect(LogText.summary(log(60, 2, 10, [10, 9, 8])) == "60 kg · 10·9") }
}

@Suite("El peso con su unidad")
struct LogTextWeightTests {
    @Test("el peso con su unidad")
    func weight() {
        #expect(LogText.weight(60) == "60 kg")
        #expect(LogText.weight(52.5) == "52,5 kg")
    }
}

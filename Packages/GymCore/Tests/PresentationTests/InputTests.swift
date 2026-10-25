import Domain
import Presentation
import Testing

// Portados de tests/unit/workout.test.js de la PWA: setParam y setRep reciben el texto del campo.

private func makeLog(weight: Double = 50, series: Int = 3, expected: Int = 10, actual: [Int?]? = nil) -> ExerciseLog {
    ExerciseLog(exerciseID: "press_banca", series: series, targetReps: expected,
                actualReps: actual ?? Array(repeating: nil, count: series), weight: weight)
}

@Suite("setParam")
struct SetParamTests {
    @Test("setParam weight con valor válido")
    func weight() { var log = makeLog(weight: 50); log.set(.weight, text: "60"); #expect(log.weight == 60) }

    @Test("setParam weight con 0 → acepta (bodyweight)")
    func weightZero() { var log = makeLog(weight: 50); log.set(.weight, text: "0"); #expect(log.weight == 0) }

    @Test("setParam weight con negativo → clamp a 0")
    func weightNegative() { var log = makeLog(weight: 50); log.set(.weight, text: "-5"); #expect(log.weight == 0) }

    @Test("setParam weight con NaN → 0")
    func weightNaN() { var log = makeLog(weight: 50); log.set(.weight, text: "abc"); #expect(log.weight == 0) }

    @Test("setParam series con valor válido")
    func series() {
        var log = makeLog(series: 3, expected: 10, actual: [10, 8, 9])
        log.set(.series, text: "4")
        #expect(log.series == 4)
        #expect(log.actualReps == [10, 8, 9, 10])
    }

    @Test("setParam series ajusta array de reps.actual (truncate)")
    func seriesTruncate() {
        var log = makeLog(series: 3, actual: [10, 8, 9])
        log.set(.series, text: "2")
        #expect(log.series == 2)
        #expect(log.actualReps == [10, 8])
    }

    @Test("setParam series con 0 → clamp a 1")
    func seriesZero() {
        var log = makeLog(series: 3, actual: [10, 8, 9])
        log.set(.series, text: "0")
        #expect(log.series == 1)
        #expect(log.actualReps == [10])
    }

    @Test("setParam repsExpected con valor válido")
    func target() { var log = makeLog(expected: 10); log.set(.targetReps, text: "12"); #expect(log.targetReps == 12) }

    @Test("setParam repsExpected con 0 → clamp a 1")
    func targetZero() { var log = makeLog(expected: 10); log.set(.targetReps, text: "0"); #expect(log.targetReps == 1) }

    @Test("setParam repsExpected sincroniza todas las reps actuales al nuevo valor")
    func targetSyncs() {
        var log = makeLog(series: 3, expected: 11, actual: [11, 11, 9])
        log.set(.targetReps, text: "12")
        #expect(log.targetReps == 12)
        #expect(log.actualReps == [12, 12, 12])
    }

    @Test("setParam repsExpected sincroniza al bajar")
    func targetSyncsDown() {
        var log = makeLog(series: 3, expected: 11, actual: [11, 11, 9])
        log.set(.targetReps, text: "8")
        #expect(log.targetReps == 8)
        #expect(log.actualReps == [8, 8, 8])
    }

    @Test("setParam repsExpected sincroniza reps null")
    func targetSyncsNulls() {
        var log = makeLog(series: 3, expected: 10, actual: [nil, nil, nil])
        log.set(.targetReps, text: "15")
        #expect(log.actualReps == [15, 15, 15])
    }

    @Test("setParam repsExpected con clamp a 1 sincroniza actuales a 1")
    func targetClampSyncs() {
        var log = makeLog(series: 2, expected: 5, actual: [5, 4])
        log.set(.targetReps, text: "0")
        #expect(log.targetReps == 1)
        #expect(log.actualReps == [1, 1])
    }

    @Test("setParam weight NO toca reps.actual")
    func weightKeepsReps() {
        var log = makeLog(weight: 50, series: 3, expected: 10, actual: [11, 9, 10])
        log.set(.weight, text: "60")
        #expect(log.actualReps == [11, 9, 10])
    }

    @Test("el peso admite coma decimal")
    func decimalComma() {
        // El teclado numérico de iOS en español escribe "52,5"; `parseFloat` de JS se quedaba en 52.
        var log = makeLog(weight: 50)
        log.set(.weight, text: "52,5")
        #expect(log.weight == 52.5)
    }
}

@Suite("setParam — casos borde")
struct SetParamEdgeCaseTests {
    @Test("series con decimal redondea")
    func rounds() { var log = makeLog(series: 3, actual: [10, 8, 9]); log.set(.series, text: "2.7"); #expect(log.series == 3) }
}

@Suite("setRep")
struct SetRepTextTests {
    @Test("establece rep a valor dado")
    func sets() { var log = makeLog(expected: 10, actual: [10, 8, 9]); log.setRep(at: 1, text: "12"); #expect(log.actualReps[1] == 12) }

    @Test("valor vacío → null (rep no completada)")
    func empty() { var log = makeLog(expected: 10, actual: [10, 8, 9]); log.setRep(at: 1, text: ""); #expect(log.actualReps[1] == nil) }

    @Test("valor NaN → null")
    func nan() { var log = makeLog(expected: 10, actual: [10, 8, 9]); log.setRep(at: 1, text: "abc"); #expect(log.actualReps[1] == nil) }

    @Test("valor 0 → acepta (0 reps completadas)")
    func zero() { var log = makeLog(expected: 10, actual: [10, 8, 9]); log.setRep(at: 1, text: "0"); #expect(log.actualReps[1] == 0) }

    @Test("valor negativo → clamp a 0")
    func negative() { var log = makeLog(expected: 10, actual: [10, 8, 9]); log.setRep(at: 1, text: "-5"); #expect(log.actualReps[1] == 0) }
}

@Suite("Lectura de números tecleados")
struct NumericInputTests {
    @Test("como parseFloat: el número del principio, ignorando lo que sigue")
    func decimal() {
        #expect(NumericInput.decimal("60") == 60)
        #expect(NumericInput.decimal(" 2.7 kg") == 2.7)
        #expect(NumericInput.decimal("-5") == -5)
        #expect(NumericInput.decimal("52,5") == 52.5)
        #expect(NumericInput.decimal(".5") == 0.5)
        #expect(NumericInput.decimal("") == nil)
        #expect(NumericInput.decimal("abc") == nil)
        #expect(NumericInput.decimal("-") == nil)
    }

    @Test("como parseInt: el entero del principio")
    func integer() {
        #expect(NumericInput.integer("12") == 12)
        #expect(NumericInput.integer("7.9") == 7)
        #expect(NumericInput.integer("-5") == -5)
        #expect(NumericInput.integer("") == nil)
        #expect(NumericInput.integer("abc") == nil)
    }
}

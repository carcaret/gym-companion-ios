import Domain
import Testing

// Portados de tests/unit/metrics.test.js de la PWA.

/// `makeLog` de metrics.test.js: sin `actual`, la lista vacía (no una serie sin rellenar por serie).
private func metricsLog(weight: Double = 50, series: Int = 3, expected: Int = 10, actual: [Int?] = []) -> ExerciseLog {
    makeLog(weight: weight, series: series, expected: expected, actual: actual)
}

@Suite("computeAvgReps")
struct AverageRepsTests {
    @Test("con reps reales usa el promedio de actual")
    func average() { #expect(isClose(metricsLog(actual: [10, 8, 10]).averageReps, 9.333, digits: 2)) }

    @Test("sin reps reales usa expected")
    func target() { #expect(metricsLog(expected: 12).averageReps == 12) }

    @Test("con una sola rep")
    func single() { #expect(metricsLog(actual: [8]).averageReps == 8) }
}

@Suite("computeVolume")
struct VolumeTests {
    @Test("con peso > 0: peso * series * avgReps")
    func weighted() { #expect(metricsLog(weight: 60, series: 4, actual: [10, 10, 10, 10]).volume == 60 * 4 * 10) }

    @Test("con peso = 0 (bodyweight): series * avgReps")
    func bodyweight() { #expect(metricsLog(weight: 0, series: 3, actual: [12, 12, 12]).volume == 3 * 12) }
}

@Suite("computeE1RM")
struct E1RMTests {
    @Test("peso > 0, series uniformes: max coincide con valor de cualquier serie")
    func uniform() { #expect(isClose(metricsLog(weight: 100, series: 3, actual: [6, 6, 6]).estimatedOneRepMax, 100 * (1 + 6.0 / 30), digits: 5)) }

    @Test("series con reps distintas: devuelve la de mayor reps (no el promedio)")
    func best() { #expect(isClose(metricsLog(weight: 90, series: 3, actual: [12, 11, 10]).estimatedOneRepMax, 90 * (1 + 12.0 / 30), digits: 5)) }

    @Test("ejemplo de la spec: 90kg × 12 reps → 126 kg")
    func spec() { #expect(isClose(metricsLog(weight: 90, series: 1, actual: [12]).estimatedOneRepMax, 126, digits: 1)) }

    @Test("peso = 0 (bodyweight) → retorna 0")
    func bodyweight() { #expect(metricsLog(weight: 0, series: 3, actual: [10, 10, 10]).estimatedOneRepMax == 0) }

    @Test("peso negativo → retorna 0")
    func negative() { #expect(metricsLog(weight: -10, series: 3, actual: [10, 10, 10]).estimatedOneRepMax == 0) }

    @Test("series=1, una rep")
    func oneRep() { #expect(isClose(metricsLog(weight: 80, series: 1, actual: [1]).estimatedOneRepMax, 80 * (1 + 1.0 / 30), digits: 5)) }

    @Test("reps = 0 en todas las series → excluidas → e1RM = 0")
    func zeroReps() { #expect(metricsLog(weight: 50, series: 3, expected: 0, actual: [0, 0, 0]).estimatedOneRepMax == 0) }

    @Test("reps > 30 en todas las series → excluidas → e1RM = 0")
    func tooMany() { #expect(metricsLog(weight: 50, series: 2, actual: [31, 35]).estimatedOneRepMax == 0) }

    @Test("mix de reps válidas e inválidas: solo considera las válidas")
    func mixed() { #expect(isClose(metricsLog(weight: 50, series: 3, actual: [0, 12, 35]).estimatedOneRepMax, 50 * (1 + 12.0 / 30), digits: 5)) }

    @Test("reps null en series incompletas → se ignoran")
    func nulls() { #expect(isClose(metricsLog(weight: 60, series: 3, expected: 10, actual: [12, nil, 10]).estimatedOneRepMax, 60 * (1 + 12.0 / 30), digits: 5)) }

    @Test("actual vacío → usa expected como rep única")
    func emptyActual() { #expect(isClose(metricsLog(weight: 50, expected: 10).estimatedOneRepMax, 50 * (1 + 10.0 / 30), digits: 5)) }

    @Test("expected > 30 sin actual → excluido → e1RM = 0")
    func bigTarget() { #expect(metricsLog(weight: 50, expected: 40).estimatedOneRepMax == 0) }

    @Test("reps = 30 (límite superior válido): se incluye")
    func upperBound() { #expect(isClose(metricsLog(weight: 40, series: 1, actual: [30]).estimatedOneRepMax, 80, digits: 5)) }

    @Test("reps = 1 (límite inferior válido): se incluye")
    func lowerBound() { #expect(isClose(metricsLog(weight: 100, series: 1, actual: [1]).estimatedOneRepMax, 100 * (1 + 1.0 / 30), digits: 5)) }
}

@Suite("computeAvgReps (edge cases)")
struct AverageRepsEdgeCaseTests {
    @Test("actual con nulls mezclados → suma incluye 0 por los nulls")
    func nullsAsZero() { #expect(isClose(metricsLog(weight: 50, series: 3, expected: 10, actual: [10, nil, 10]).averageReps, 6.667, digits: 2)) }

    @Test("actual todo nulls → reduce da 0/N = 0")
    func allNull() { #expect(metricsLog(weight: 50, series: 3, expected: 10, actual: [nil, nil, nil]).averageReps == 0) }

    @Test("actual vacío [] → cae al else, retorna expected")
    func empty() { #expect(metricsLog(expected: 12).averageReps == 12) }
}

@Suite("computeVolume (edge cases)")
struct VolumeEdgeCaseTests {
    @Test("series=0 → volumen 0")
    func zeroSeries() { #expect(metricsLog(weight: 50, series: 0, expected: 10, actual: []).volume == 0) }

    @Test("reps all null (avgReps=0) → volumen 0")
    func allNull() { #expect(metricsLog(weight: 50, series: 3, expected: 10, actual: [nil, nil, nil]).volume == 0) }
}

@Suite("computeSessionDeltaPct")
struct SessionDeltaTests {
    @Test("mejora real → devuelve porcentaje positivo")
    func up() { #expect(Metrics.sessionDeltaPercent(current: 110, previous: 100) == 10) }

    @Test("bajada real → devuelve porcentaje negativo")
    func down() { #expect(Metrics.sessionDeltaPercent(current: 90, previous: 100) == -10) }

    @Test("sin cambio → devuelve null")
    func same() { #expect(Metrics.sessionDeltaPercent(current: 100, previous: 100) == nil) }

    @Test("prevMetric = 0 → devuelve null (evita división por cero)")
    func zero() { #expect(Metrics.sessionDeltaPercent(current: 100, previous: 0) == nil) }

    @Test("prevMetric negativo → devuelve null")
    func negative() { #expect(Metrics.sessionDeltaPercent(current: 100, previous: -50) == nil) }

    @Test("cambio menor de 0.5% que redondea a 0 → devuelve null")
    func tiny() { #expect(Metrics.sessionDeltaPercent(current: 100.4, previous: 100) == nil) }

    @Test("redondeo correcto: 10.5% → 11")
    func rounding() {
        // Como en la PWA: pese al nombre, el caso que se comprueba es 210 frente a 200 (5 %).
        #expect(Metrics.sessionDeltaPercent(current: 210, previous: 200) == 5)
    }
}

/// `makeFullLog` de metrics.test.js.
private func fullLog(_ id: ExerciseID, weight: Double = 50, series: Int = 3, actual: [Int?] = [10, 10, 10]) -> ExerciseLog {
    makeLog(id, weight: weight, series: series, expected: 10, actual: actual)
}

private func entry(_ date: LocalDate, _ logs: [ExerciseLog]) -> Session {
    makeSession(date, completed: true, logs: logs)
}

@Suite("getMaxMetrics")
struct MaxMetricsTests {
    @Test("devuelve máximos de volumen y e1RM para un ejercicio")
    func maxima() {
        let entries = [
            entry("2026-01-01", [fullLog("press", weight: 50, series: 3, actual: [10, 10, 10])]),
            entry("2026-01-02", [fullLog("press", weight: 60, series: 3, actual: [8, 8, 8])]),
        ]
        let result = entries.maxMetrics(for: "press")
        #expect(result.volume == 1500)
        #expect(isClose(result.estimatedOneRepMax, 76, digits: 0))
    }

    @Test("ignora ejercicios que no coinciden")
    func otherExercises() {
        let entries = [entry("2026-01-01", [fullLog("press", weight: 100), fullLog("curl", weight: 20)])]
        #expect(entries.maxMetrics(for: "curl").volume == 20 * 3 * 10)
    }

    @Test("historial vacío → maxVolume=0, maxE1RM=0")
    func empty() {
        let result = [Session]().maxMetrics(for: "press")
        #expect(result.volume == 0)
        #expect(result.estimatedOneRepMax == 0)
    }

    @Test("ejercicio no encontrado → maxVolume=0, maxE1RM=0")
    func notFound() {
        let result = [entry("2026-01-01", [fullLog("press")])].maxMetrics(for: "sentadilla")
        #expect(result.volume == 0)
        #expect(result.estimatedOneRepMax == 0)
    }

    @Test("ignora los logs saltados al calcular máximos")
    func skipped() {
        var skippedLog = fullLog("press", weight: 100, actual: [8, 8, 8])
        skippedLog.skipped = true
        let entries = [entry("2026-01-01", [skippedLog]), entry("2026-01-02", [fullLog("press", weight: 80, actual: [8, 8, 8])])]
        let result = entries.maxMetrics(for: "press")
        #expect(result.volume == 80 * 3 * 8)
        #expect(isClose(result.estimatedOneRepMax, 80 * (1 + 8.0 / 30), digits: 5))
    }

    @Test("max e1RM es el de la mejor serie de la mejor sesión")
    func bestSet() {
        let entries = [
            entry("2026-01-01", [fullLog("press", weight: 90, actual: [12, 8])]),
            entry("2026-01-02", [fullLog("press", weight: 90, actual: [10, 10])]),
        ]
        #expect(isClose(entries.maxMetrics(for: "press").estimatedOneRepMax, 90 * (1 + 12.0 / 30), digits: 5))
    }
}

/// `computeRepShortfall` no tiene tests en la PWA; se añaden con los casos de su comentario.
@Suite("computeRepShortfall")
struct RepShortfallTests {
    @Test("suma lo que faltó en cada serie rellenada")
    func sums() { #expect(makeLog(expected: 10, actual: [10, 8, 7]).repShortfall == 5) }

    @Test("las series vacías no cuentan (entreno en curso)")
    func ignoresEmpty() { #expect(makeLog(expected: 10, actual: [9, nil, nil]).repShortfall == 1) }

    @Test("superar el objetivo no compensa otra serie")
    func noCompensation() { #expect(makeLog(expected: 10, actual: [12, 8]).repShortfall == 2) }

    @Test("objetivo cumplido en todas → 0")
    func met() { #expect(makeLog(expected: 10, actual: [10, 11, 10]).repShortfall == 0) }
}

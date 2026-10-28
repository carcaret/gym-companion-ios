import Domain
import Presentation
import Testing

// Port de tests/unit/bar-colors.test.js: color de cada barra de la tira. Azul = objetivo cumplido
// (o peso distinto), verde = mismo peso sin cumplir; la intensidad, relativa a su grupo.
//
// Cambio aprobado por el usuario el 2026-10-28 (repaso de la HIG, B4): lo que la PWA pinta en verde
// la app lo pinta en naranja, el color de «por debajo del objetivo» en toda la app. Los tests
// conservan el nombre de la PWA («verde»); cambian los colores esperados (`belowVivid`,
// `belowFloor`) y, en el último, que domine el rojo en vez del verde.

private func makeLog(weight: Double = 100, series: Int = 3, expected: Int = 10, actual: [Int?] = []) -> ExerciseLog {
    ExerciseLog(exerciseID: "press", series: series, targetReps: expected, actualReps: actual, weight: weight)
}

private let blueFloor = "rgb(30,58,80)"
private let blueVivid = "rgb(86,156,214)"
private let belowVivid = "rgb(206,145,120)"
private let belowFloor = "rgb(103,72,60)"
private let noBelowTarget = BelowTargetScale(useE1RM: false, range: 0...0)

private func color(_ log: ExerciseLog, _ blueRange: ClosedRange<Double>, _ green: BelowTargetScale, _ reference: Double? = nil) -> RGB {
    BarColor.color(log, blueRange: blueRange, belowTargetScale: green, referenceWeight: reference)
}

@Suite("computeRepShortfall")
struct RepShortfallTests {
    @Test("todas las series clavan el objetivo → 0")
    func exact() { #expect(makeLog(expected: 10, actual: [10, 10, 10]).repShortfall == 0) }

    @Test("todas superan el objetivo → 0 (no negativo)")
    func above() { #expect(makeLog(expected: 10, actual: [12, 11, 13]).repShortfall == 0) }

    @Test("una serie corta → déficit de esa serie")
    func oneShort() { #expect(makeLog(expected: 10, actual: [10, 10, 9]).repShortfall == 1) }

    @Test("mismo total de reps → mismo shortfall (independiente del orden)")
    func order() {
        let a = makeLog(expected: 10, actual: [10, 10, 9]).repShortfall
        let b = makeLog(expected: 10, actual: [10, 9, 10]).repShortfall
        #expect(a == b)
        #expect(a == 1)
    }

    @Test("varias cortas → suma de faltantes")
    func several() {
        #expect(makeLog(expected: 10, actual: [10, 10, 8]).repShortfall == 2)
        #expect(makeLog(expected: 10, actual: [9, 8, 8]).repShortfall == 5)
    }

    @Test("mezcla superadas y cortas → solo cuentan las cortas")
    func mixed() { #expect(makeLog(expected: 10, actual: [12, 8, 10]).repShortfall == 2) }

    @Test("series sin rellenar (null) se ignoran — entreno en curso")
    func empty() {
        #expect(makeLog(expected: 10, actual: [10, 9, nil]).repShortfall == 1)
        #expect(makeLog(expected: 10, actual: [nil, nil, nil]).repShortfall == 0)
    }

    @Test("actual vacío → 0")
    func noActual() { #expect(makeLog(expected: 10, actual: []).repShortfall == 0) }
}

@Suite("isGreenBar")
struct IsGreenBarTests {
    @Test("objetivo cumplido → nunca verde")
    func met() { #expect(!BarColor.isBelowTarget(makeLog(expected: 10, actual: [10, 10, 10]))) }

    @Test("objetivo no cumplido, sin peso de referencia → verde")
    func short() { #expect(BarColor.isBelowTarget(makeLog(expected: 10, actual: [10, 10, 8]))) }

    @Test("objetivo no cumplido, mismo peso que la referencia → verde")
    func sameWeight() { #expect(BarColor.isBelowTarget(makeLog(weight: 60, expected: 10, actual: [10, 10, 8]), referenceWeight: 60)) }

    @Test("objetivo no cumplido, peso distinto de la referencia → no verde (azul)")
    func otherWeight() {
        let log = makeLog(weight: 60, expected: 10, actual: [10, 10, 8])
        #expect(!BarColor.isBelowTarget(log, referenceWeight: 80))
        #expect(!BarColor.isBelowTarget(log, referenceWeight: 40))
    }

    @Test("peso 0 en ambos (corporal) → cuenta como mismo peso")
    func bodyweight() { #expect(BarColor.isBelowTarget(makeLog(weight: 0, expected: 10, actual: [10, 10, 9]), referenceWeight: 0)) }
}

@Suite("computeBarColor — objetivo cumplido (o peso distinto) → AZUL, relativo al grupo azul")
struct BlueBarTests {
    private let log = makeLog(expected: 10, actual: [10, 10, 10])
    private var metric: Double { log.primaryMetric }

    @Test("única barra azul del grupo → azul vívido (tope), sea cual sea su e1RM")
    func single() { #expect(color(log, metric...metric, noBelowTarget).text == blueVivid) }

    @Test("mínimo e1RM del grupo azul → suelo")
    func floor() { #expect(color(log, metric...(metric + 100), noBelowTarget).text == blueFloor) }

    @Test("máximo e1RM del grupo azul → vívido")
    func vivid() { #expect(color(log, (metric - 100)...metric, noBelowTarget).text == blueVivid) }

    @Test("e1RM intermedio → azul entre suelo y vívido")
    func middle() { #expect(color(log, (metric - 50)...(metric + 50), noBelowTarget) == RGB(r: 58, g: 107, b: 147)) }

    @Test("más e1RM relativo al grupo → azul más claro (canal G sube)")
    func brighter() {
        let low = color(log, metric...(metric + 100), noBelowTarget)
        let high = color(log, (metric - 100)...metric, noBelowTarget)
        #expect(high.g > low.g)
    }

    @Test("peso distinto de la referencia (aunque no cumpla objetivo) → grupo azul")
    func otherWeight() {
        let short = makeLog(weight: 60, expected: 10, actual: [10, 10, 8])
        let m = short.primaryMetric
        #expect(color(short, m...m, noBelowTarget, 80).text == blueVivid)
        #expect(color(short, m...(m + 100), noBelowTarget, 80).text == blueFloor)
    }
}

@Suite("buildBelowTargetScale — la intensidad del verde sale del volumen, no del objetivo")
struct BelowTargetScaleTests {
    @Test("grupo vacío → rango neutro")
    func empty() { #expect(BarColor.belowTargetScale([]) == BelowTargetScale(useE1RM: false, range: 0...0)) }

    @Test("volúmenes distintos → escala por volumen")
    func volumes() {
        let a = makeLog(weight: 68, series: 4, expected: 10, actual: [10, 10, 10, 9])
        let b = makeLog(weight: 68, series: 4, expected: 11, actual: [11, 10, 10, 10])
        let scale = BarColor.belowTargetScale([a, b])
        #expect(!scale.useE1RM)
        #expect(scale.range == (68 * 39)...(68 * 41))
    }

    @Test("todas empatan en volumen → desempata por e1RM")
    func tie() {
        let a = makeLog(weight: 68, series: 3, expected: 13, actual: [12, 10, 10])
        let b = makeLog(weight: 68, series: 3, expected: 13, actual: [11, 11, 10])
        let scale = BarColor.belowTargetScale([a, b])
        #expect(scale.useE1RM)
        #expect(scale.range == b.primaryMetric...a.primaryMetric)
    }
}

@Suite("computeBarColor — mismo peso y objetivo NO cumplido → VERDE, relativo al grupo verde")
struct GreenBarTests {
    private func scale(_ logs: [ExerciseLog]) -> BelowTargetScale { BarColor.belowTargetScale(logs) }

    @Test("única barra verde del grupo → vívida (tope), por mal que fuera la sesión")
    func single() {
        let solo = makeLog(expected: 10, actual: [10, 6, 8])
        #expect(color(solo, 0...0, scale([solo])).text == belowVivid)
    }

    @Test("caso real del jalón: más reps con objetivo más alto → la más vívida")
    func realCase() {
        let jul24 = makeLog(weight: 68, series: 4, expected: 10, actual: [10, 10, 10, 9])
        let ago14 = makeLog(weight: 68, series: 4, expected: 10, actual: [10, 10, 10, 9])
        let ago21 = makeLog(weight: 68, series: 4, expected: 11, actual: [11, 10, 10, 10])
        let s = scale([jul24, ago14, ago21])
        #expect(color(ago21, 0...0, s, 68).text == belowVivid)
        #expect(color(jul24, 0...0, s, 68).text == belowFloor)
        #expect(color(ago14, 0...0, s, 68).text == belowFloor)
    }

    @Test("un objetivo inflado no da color: manda lo ejecutado")
    func inflated() {
        let inflado = makeLog(weight: 68, series: 3, expected: 20, actual: [10, 10, 10])
        let sano = makeLog(weight: 68, series: 3, expected: 10, actual: [10, 10, 9])
        let s = scale([inflado, sano])
        #expect(color(inflado, 0...0, s, 68).text == belowVivid)
        #expect(color(sano, 0...0, s, 68).text == belowFloor)
    }

    @Test("más series = más trabajo = más vívida")
    func moreSeries() {
        let tres = makeLog(weight: 68, series: 3, expected: 10, actual: [10, 10, 9])
        let cinco = makeLog(weight: 68, series: 5, expected: 10, actual: [10, 10, 10, 10, 9])
        let s = scale([tres, cinco])
        #expect(color(cinco, 0...0, s, 68).text == belowVivid)
        #expect(color(tres, 0...0, s, 68).text == belowFloor)
    }

    @Test("empate de volumen → desempata el pico de la mejor serie (e1RM)")
    func tieBreak() {
        let pico12 = makeLog(weight: 68, series: 3, expected: 13, actual: [12, 10, 10])
        let pico11 = makeLog(weight: 68, series: 3, expected: 13, actual: [11, 11, 10])
        let s = scale([pico12, pico11])
        #expect(color(pico12, 0...0, s, 68).text == belowVivid)
        #expect(color(pico11, 0...0, s, 68).text == belowFloor)
    }

    @Test("mismo trabajo y mismo pico → mismo color (empate real)")
    func realTie() {
        let a = makeLog(weight: 68, series: 3, expected: 13, actual: [12, 10, 10])
        let b = makeLog(weight: 68, series: 3, expected: 13, actual: [10, 12, 10])
        let s = scale([a, b])
        #expect(color(a, 0...0, s, 68) == color(b, 0...0, s, 68))
    }

    @Test("monótono: a más volumen relativo, verde más vívido (G sube, nunca baja)")
    func monotonic() {
        let logs = (4...10).map { r in makeLog(weight: 68, series: 3, expected: 12, actual: [r, r, r]) }
        let s = scale(logs)
        var previous = Int.min
        for log in logs {
            let current = color(log, 0...0, s, 68).g
            #expect(current >= previous)
            previous = current
        }
    }

    @Test("mismo peso pero objetivo cumplido → grupo azul (el peso no fuerza verde)")
    func metSameWeight() {
        let met = makeLog(weight: 60, expected: 10, actual: [10, 10, 10])
        let m = met.primaryMetric
        #expect(color(met, m...m, noBelowTarget, 60).text == blueVivid)
    }

    @Test("peso 0 en ambos (corporal) → cuenta como mismo peso → verde")
    func bodyweight() {
        let bw = makeLog(weight: 0, expected: 10, actual: [10, 10, 9])
        #expect(color(bw, 0...0, scale([bw]), 0).text == belowVivid)
    }
}

@Suite("computeBarColor — azul vs verde son distinguibles")
struct BarColorContrastTests {
    @Test("cumplido es azulado (B alto), no cumplido es verdoso (G domina)")
    func contrast() {
        let met = makeLog(expected: 10, actual: [10, 10, 10])
        let short = makeLog(expected: 10, actual: [10, 10, 8])
        let m = met.primaryMetric
        let azul = color(met, m...m, noBelowTarget)
        let naranja = color(short, 0...0, BarColor.belowTargetScale([short]))
        #expect(azul.b > azul.g)
        // En la PWA, `verde.g > verde.b`; en naranja domina el rojo (aprobado el 2026-10-28).
        #expect(naranja.r > naranja.b)
    }
}

import Domain
import Presentation
import Testing

// Las reps se separan con «·» y la serie vacía es «—» (cambiado con la aprobación del usuario,
// 2026-10-27; en la PWA, «10-8-10» y «10---8»).

// Port de tests/unit/builders.test.js: la tira "Últimas sesiones" de cada ejercicio, el delta
// "vs última" y los chips de reps. En la PWA se comprueba el HTML; aquí, el contenido de la tira.

private func day(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }

/// `dbWith` de la PWA: una sesión terminada por fecha con un log de `press`.
private func history(_ logsByDate: [(String, ExerciseLog)]) -> [Session] {
    logsByDate.map { Session(date: day($0.0), routineID: "DIA1", completed: true, logs: [$0.1]) }
}

private func log(series: Int, expected: Int, actual: [Int?], weight: Double, skipped: Bool = false) -> ExerciseLog {
    ExerciseLog(exerciseID: "press", series: series, targetReps: expected, actualReps: actual, weight: weight, skipped: skipped)
}

private func pullup(_ weight: Double, _ actual: [Int?]) -> ExerciseLog {
    log(series: actual.count, expected: 10, actual: actual, weight: weight)
}

@Suite("buildHistoryStripHtml con saltados")
struct HistoryStripSkippedTests {
    @Test("pinta la sesión saltada como columna fantasma en su sitio")
    func skippedColumn() throws {
        let sessions = history([
            ("2026-06-01", log(series: 3, expected: 8, actual: [8, 8, 8], weight: 80)),
            ("2026-06-08", log(series: 3, expected: 8, actual: [0, 0, 0], weight: 0, skipped: true)),
        ])
        let current = log(series: 3, expected: 8, actual: [9, 9, 9], weight: 85)
        let strip = try #require(HistoryStrip.make(history: sessions, exercise: "press", current: current, anchor: day("2026-06-15")))
        #expect(strip.bars.map(\.dateLabel).suffix(3) == ["1/6", "8/6", "15/6"])
        #expect(strip.bars[4].kind == .skipped)
    }

    @Test("el delta \"% vs última\" ignora la sesión saltada y usa la real previa")
    func deltaIgnoresSkipped() throws {
        let sessions = history([
            ("2026-06-01", log(series: 3, expected: 8, actual: [8, 8, 8], weight: 80)),
            ("2026-06-08", log(series: 3, expected: 8, actual: [0, 0, 0], weight: 0, skipped: true)),
        ])
        // Igual que la real previa → delta 0 → sin delta (contra la saltada saldría enorme).
        let current = log(series: 3, expected: 8, actual: [8, 8, 8], weight: 80)
        let strip = try #require(HistoryStrip.make(history: sessions, exercise: "press", current: current, anchor: day("2026-06-15")))
        #expect(strip.delta == nil)
    }
}

@Suite("computeSessionDelta")
struct SessionDeltaTests {
    @Test("de peso corporal a lastrado → sube por la carga, aunque haya menos reps")
    func toLoaded() {
        #expect(HistoryStrip.delta(current: pullup(5, [8, 8, 7, 6]), previous: pullup(0, [10, 10, 10, 10])) == SessionDelta(up: true, label: "+5 kg"))
    }

    @Test("de lastrado a peso corporal → baja por la carga")
    func toBodyweight() {
        #expect(HistoryStrip.delta(current: pullup(0, [12, 12, 12, 12]), previous: pullup(5, [8, 8, 8, 8])) == SessionDelta(up: false, label: "-5 kg"))
    }

    @Test("los dos a peso corporal → % de reps")
    func bothBodyweight() {
        #expect(HistoryStrip.delta(current: pullup(0, [11, 11, 11, 11]), previous: pullup(0, [10, 10, 10, 10])) == SessionDelta(up: true, label: "+10%"))
    }

    @Test("los dos lastrados → % de e1RM")
    func bothLoaded() {
        #expect(HistoryStrip.delta(current: pullup(5, [8, 8, 8, 8]), previous: pullup(10, [8, 8, 8, 8])) == SessionDelta(up: false, label: "-50%"))
    }

    @Test("sin cambio → null")
    func noChange() {
        #expect(HistoryStrip.delta(current: pullup(0, [10, 10, 10, 10]), previous: pullup(0, [10, 10, 10, 10])) == nil)
    }
}

@Suite("computeStripLevels")
struct StripLevelsTests {
    @Test("sin mezcla → métrica entre el máximo")
    func plain() {
        #expect(HistoryStrip.levels([pullup(0, [5, 5]), pullup(0, [10, 10])]) == [0.5, 1])
    }

    @Test("mezcla sin lastre y lastrado → las lastradas siempre por encima")
    func mixed() {
        let levels = HistoryStrip.levels([pullup(0, [10, 10, 10, 10]), pullup(0, [10, 10, 10, 9]), pullup(5, [6, 6, 6, 6])])
        #expect(abs(levels[0] - 0.5) < 0.005)
        #expect(abs(levels[1] - 0.5 * 39 / 40) < 0.005)
        #expect(levels[2] == 1)
    }

    @Test("mezcla: dentro del grupo lastrado manda la proporción de e1RM")
    func mixedLoaded() {
        let levels = HistoryStrip.levels([pullup(0, [10]), pullup(5, [6]), pullup(10, [6])])
        #expect(abs(levels[1] - 0.75) < 0.005)
        #expect(levels[2] == 1)
    }
}

@Suite("buildHistoryStripHtml con lastre en un ejercicio de peso corporal")
struct HistoryStripWeightedTests {
    @Test("primera sesión lastrada → delta en kg hacia arriba y barra actual al máximo")
    func firstWeighted() throws {
        let sessions = history([
            ("2026-09-14", log(series: 4, expected: 10, actual: [10, 10, 10, 9], weight: 0)),
            ("2026-09-23", log(series: 4, expected: 10, actual: [10, 10, 10, 10], weight: 0)),
        ])
        let strip = try #require(HistoryStrip.make(history: sessions, exercise: "press", current: pullup(5, [8, 8, 7, 7]), anchor: day("2026-10-14")))
        #expect(strip.deltaText == "↑ +5 kg vs última")
        guard case .session(let height, _, let isCurrent, _) = strip.bars.last?.kind else {
            Issue.record("la última barra no es una sesión")
            return
        }
        #expect(isCurrent)
        #expect(height == 100)
    }
}

@Suite("buildChipValues")
struct ChipValuesTests {
    @Test("centra ventana de 5 alrededor del valor")
    func centered() { #expect(RepChips.values(around: 8) == [6, 7, 8, 9, 10]) }

    @Test("current=1 → borde inferior clampado a 0, desliza hacia arriba")
    func one() { #expect(RepChips.values(around: 1) == [0, 1, 2, 3, 4]) }

    @Test("current=0 → ventana desde 0")
    func zero() { #expect(RepChips.values(around: 0) == [0, 1, 2, 3, 4]) }

    @Test("current=2 → borde a 0, no negativos")
    func two() { #expect(RepChips.values(around: 2) == [0, 1, 2, 3, 4]) }

    @Test("current alto → ventana centrada sin clamp")
    func high() { #expect(RepChips.values(around: 20) == [18, 19, 20, 21, 22]) }
}

@Suite("Tira de historial")
struct HistoryStripTests {
    @Test("seis columnas como mucho, con huecos vacíos delante si hay menos sesiones")
    func columns() throws {
        let sessions = history([("2026-06-01", log(series: 3, expected: 8, actual: [8, 8, 8], weight: 80))])
        let strip = try #require(HistoryStrip.make(history: sessions, exercise: "press", current: log(series: 3, expected: 8, actual: [9, 9, 9], weight: 80), anchor: day("2026-06-08")))
        #expect(strip.bars.count == 6)
        #expect(strip.bars.prefix(4).allSatisfy { $0.kind == .empty })
    }

    @Test("sin sesiones y sin nada hecho hoy no hay tira")
    func empty() {
        #expect(HistoryStrip.make(history: [], exercise: "press", current: log(series: 3, expected: 8, actual: [nil, nil, nil], weight: 0), anchor: day("2026-06-08")) == nil)
    }

    @Test("cada barra dice su e1RM y lo hecho (el tooltip de la PWA)")
    func tooltip() {
        // Los kilos con espacio y coma decimal, como en el resto de la app (la PWA: "80kg",
        // "73.3kg"); cambio aprobado por el usuario, 2026-10-27.
        #expect(HistoryStrip.tooltip(log(series: 3, expected: 10, actual: [10, 10, 8], weight: 60)) == "e1RM 80 kg\n60 kg · 10·10·8")
        #expect(HistoryStrip.tooltip(log(series: 3, expected: 10, actual: [10, 10, 8], weight: 55)) == "e1RM 73,3 kg\n55 kg · 10·10·8")
        #expect(HistoryStrip.tooltip(log(series: 2, expected: 10, actual: [10, nil], weight: 0)) == "10·—")
    }
}

@Suite("Lo que enseña cada barra de la tira")
struct StripBarTests {
    private let session = StripBar(kind: .session(height: 50, color: RGB(r: 0, g: 0, b: 0), isCurrent: true,
                                                  detail: BarDetail(e1RM: "e1RM 80 kg", done: "60 kg · 10·10·8")), dateLabel: "1/6")

    @Test("el bocadillo: el peso y las reps arriba, el e1RM debajo")
    func bubble() {
        #expect(session.bubble?.main == "60 kg · 10·10·8")
        #expect(session.bubble?.secondary == "e1RM 80 kg")
        let oneLine = StripBar(kind: .session(height: 50, color: RGB(r: 0, g: 0, b: 0), isCurrent: false, detail: BarDetail(e1RM: nil, done: "10·—")), dateLabel: "2/6")
        #expect(oneLine.bubble?.main == "10·—")
        #expect(oneLine.bubble?.secondary == nil)
        #expect(StripBar(kind: .skipped, dateLabel: "3/6").bubble == nil)
    }

    @Test("VoiceOver lee el detalle en una línea; sin sesión, la fecha")
    func accessibility() {
        #expect(session.accessibilityText == "e1RM 80 kg · 60 kg · 10·10·8")
        #expect(StripBar(kind: .empty, dateLabel: "").accessibilityText == "")
        #expect(StripBar(kind: .skipped, dateLabel: "3/6").accessibilityText == "3/6")
    }

    @Test("solo las sesiones se tocan, y la de hoy se marca")
    func selectable() {
        #expect(session.isSelectable && session.isCurrent)
        #expect(!StripBar(kind: .skipped, dateLabel: "3/6").isSelectable)
        #expect(!StripBar(kind: .empty, dateLabel: "").isCurrent)
    }
}

import Domain
import Testing

// Portados de tests/unit/stats.test.js de la PWA y de "los secundarios editados alimentan
// Progreso" (catalog.test.js). formatSpan, buildExercisePhrase y la frase de cada fila, en
// PresentationTests.

/// `log` de stats.test.js.
private func statsLog(_ id: ExerciseID = "press", weight: Double = 20, series: Int = 3, expected: Int = 10, actual: [Int?] = []) -> ExerciseLog {
    makeLog(id, weight: weight, series: series, expected: expected, actual: actual)
}

private func entry(_ date: LocalDate, _ log: ExerciseLog) -> Session {
    makeSession(date, completed: true, logs: [log])
}

/// `dbWith` de stats.test.js.
private func dataWith(_ sessions: [Session]) -> TrainingData {
    TrainingData(catalog: Catalog([exercise("press", "Press de prueba", .hombros)]),
                 routines: [Routine(id: "DIA1", name: "1", exerciseIDs: ["press"])], history: sessions)
}

@Suite("computeTotalReps")
struct TotalRepsTests {
    @Test("suma las reps ejecutadas")
    func sums() { #expect(statsLog(actual: [11, 11, 10]).totalReps == 32) }

    @Test("ignora las series sin rellenar")
    func ignoresEmpty() { #expect(statsLog(actual: [11, nil, nil]).totalReps == 11) }

    @Test("sin reps ejecutadas devuelve 0")
    func zero() { #expect(statsLog(actual: []).totalReps == 0) }
}

@Suite("getExerciseSessions")
struct ExerciseSessionsTests {
    private let history = [
        entry("2026-06-01", statsLog(actual: [10])),
        entry("2026-07-01", statsLog(actual: [11])),
        entry("2026-08-01", makeLog("press", weight: 20, series: 3, expected: 10, actual: [12], skipped: true)),
        entry("2026-08-10", statsLog("otro", actual: [9])),
    ]

    @Test("devuelve solo las sesiones del ejercicio, en orden ascendente")
    func onlyExercise() {
        #expect(history.sessions(of: "press", from: "2026-01-01", to: "2026-12-31").map(\.date) == ["2026-06-01", "2026-07-01"])
    }

    @Test("excluye las sesiones saltadas")
    func skipsSkipped() {
        #expect(!history.sessions(of: "press", from: "2026-01-01", to: "2026-12-31").contains { $0.date == "2026-08-01" })
    }

    @Test("respeta el rango de fechas")
    func range() {
        #expect(history.sessions(of: "press", from: "2026-06-15", to: "2026-12-31").map(\.date) == ["2026-07-01"])
    }
}

@Suite("analyzeExercise")
struct AnalyzeExerciseTests {
    @Test("estancado: mismo peso y sin superar el mejor total")
    func stalled() {
        let data = dataWith([
            entry("2026-06-05", statsLog(weight: 18, actual: [11, 11, 10])),
            entry("2026-06-12", statsLog(weight: 18, actual: [11, 11, 10])),
            entry("2026-06-19", statsLog(weight: 18, actual: [11, 10, 9])),
            entry("2026-06-26", statsLog(weight: 18, actual: [11, 11, 10])),
        ])
        let r = data.progress(of: "press", anchor: "2026-06-26", weeks: 8)
        #expect(r.status == .stalled)
        #expect(r.stallSessions == 4)
        #expect(r.bestReps == 32)
        #expect(r.weight == 18)
    }

    @Test("progresa por peso aunque las reps bajen")
    func weightUp() {
        let data = dataWith([
            entry("2026-06-05", statsLog(weight: 220, actual: [12, 12, 12, 12])),
            entry("2026-06-12", statsLog(weight: 230, actual: [10, 10, 10, 10])),
            entry("2026-06-19", statsLog(weight: 240, actual: [8, 9, 9, 9])),
        ])
        let r = data.progress(of: "press", anchor: "2026-06-19", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.stallSessions == 0)
        #expect(r.weightFrom == 220)
        #expect(r.weightTo == 240)
    }

    @Test("progresa por reps al mismo peso")
    func repsUp() {
        let data = dataWith([
            entry("2026-06-05", statsLog(weight: 68, actual: [10, 10, 9, 9])),
            entry("2026-06-12", statsLog(weight: 68, actual: [10, 10, 10, 9])),
            entry("2026-06-19", statsLog(weight: 68, actual: [11, 10, 10, 10])),
        ])
        let r = data.progress(of: "press", anchor: "2026-06-19", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.repsFrom == 38)
        #expect(r.repsTo == 41)
    }

    @Test("no usa reps.expected: fallar el objetivo mientras suben las reps es progreso")
    func ignoresTarget() {
        let data = dataWith([
            entry("2026-06-05", statsLog(weight: 68, expected: 10, actual: [10, 10, 9, 9])),
            entry("2026-06-12", statsLog(weight: 68, expected: 10, actual: [10, 10, 10, 9])),
            entry("2026-06-19", statsLog(weight: 68, expected: 11, actual: [11, 10, 10, 10])),
        ])
        #expect(data.progress(of: "press", anchor: "2026-06-19", weeks: 8).status == .progressing)
    }

    @Test("sin recorrido con menos de 3 sesiones")
    func noTrack() {
        let data = dataWith([
            entry("2026-06-12", statsLog(weight: 0, actual: [9, 9, 9, 7])),
            entry("2026-06-19", statsLog(weight: 0, actual: [9, 9, 9, 8])),
        ])
        let r = data.progress(of: "press", anchor: "2026-06-19", weeks: 8)
        #expect(r.status == .noTrack)
        #expect(r.stallSessions == 0)
    }

    @Test("recentReps trae las 3 últimas sesiones, la más antigua primero")
    func recentReps() {
        let data = dataWith([
            entry("2026-06-05", statsLog(weight: 18, actual: [1])),
            entry("2026-06-12", statsLog(weight: 18, actual: [2])),
            entry("2026-06-19", statsLog(weight: 18, actual: [3])),
            entry("2026-06-26", statsLog(weight: 18, actual: [4])),
        ])
        #expect(data.progress(of: "press", anchor: "2026-06-26", weeks: 8).recentReps == [[2], [3], [4]])
    }

    @Test("la racha arranca en la última sesión que batió el récord, no antes")
    func streakStart() {
        let data = dataWith([
            entry("2026-05-01", statsLog(weight: 18, actual: [10, 10, 10])),
            entry("2026-05-08", statsLog(weight: 18, actual: [11, 11, 10])),
            entry("2026-05-15", statsLog(weight: 18, actual: [11, 11, 10])),
            entry("2026-05-22", statsLog(weight: 18, actual: [11, 10, 10])),
        ])
        let r = data.progress(of: "press", anchor: "2026-05-22", weeks: 8)
        #expect(r.stallSessions == 3)
        #expect(r.stallSince == "2026-05-08")
        #expect(r.bestReps == 32)
    }

    @Test("empatar el récord seis veces cuenta las seis sesiones")
    func sixTies() {
        let data = dataWith(["2026-05-01", "2026-05-08", "2026-05-15", "2026-05-22", "2026-05-29", "2026-06-05"]
            .map { entry(LocalDate($0), statsLog(weight: 97, actual: [9, 9, 9])) })
        let r = data.progress(of: "press", anchor: "2026-06-05", weeks: 8)
        #expect(r.status == .stalled)
        #expect(r.stallSessions == 6)
    }

    @Test("la racha solo cuenta sesiones al peso actual")
    func streakAtWeight() {
        let data = dataWith([
            entry("2026-01-10", statsLog(weight: 16, actual: [12, 12, 12])),
            entry("2026-06-05", statsLog(weight: 18, actual: [10, 10, 10])),
            entry("2026-06-12", statsLog(weight: 18, actual: [10, 10, 10])),
            entry("2026-06-19", statsLog(weight: 18, actual: [10, 10, 10])),
        ])
        let r = data.progress(of: "press", anchor: "2026-06-19", weeks: 8)
        #expect(r.status == .stalled)
        #expect(r.stallSessions == 3)
    }

    @Test("subir de peso es progreso, aunque a la carga nueva aún no se mejore")
    func weightUpNoReps() {
        let data = dataWith([
            entry("2026-06-05", statsLog(weight: 16, actual: [12, 12, 12])),
            entry("2026-06-12", statsLog(weight: 18, actual: [10, 10, 10])),
            entry("2026-06-19", statsLog(weight: 18, actual: [10, 10, 10])),
        ])
        let r = data.progress(of: "press", anchor: "2026-06-19", weeks: 8)
        #expect(r.status == .progressing)
        #expect(r.stallSessions == 0)
    }

    @Test("el span de una subida de peso se mide desde la última sesión con la carga vieja")
    func span() {
        let data = dataWith([
            entry("2026-05-01", statsLog(weight: 220, actual: [12, 12])),
            entry("2026-06-05", statsLog(weight: 220, actual: [12, 12])),
            entry("2026-06-12", statsLog(weight: 230, actual: [10, 10])),
            entry("2026-06-19", statsLog(weight: 240, actual: [9, 9])),
        ])
        #expect(data.progress(of: "press", anchor: "2026-06-19", weeks: 8).spanDays == 14)
    }
}

@Suite("buildExerciseRows")
struct ExerciseRowsTests {
    static let three = TrainingData(
        catalog: Catalog([exercise("a", "Aaa"), exercise("b", "Bbb"), exercise("c", "Ccc")]),
        routines: [Routine(id: "DIA1", name: "1", exerciseIDs: ["a", "b", "c"])],
        history: [
            makeSession("2026-06-05", completed: true, logs: [statsLog("a", weight: 10, actual: [10]), statsLog("b", weight: 10, actual: [8])]),
            makeSession("2026-06-12", completed: true, logs: [statsLog("a", weight: 10, actual: [10]), statsLog("b", weight: 10, actual: [9])]),
            makeSession("2026-06-19", completed: true, logs: [statsLog("a", weight: 10, actual: [10]), statsLog("b", weight: 10, actual: [10]), statsLog("c", weight: 10, actual: [10])]),
        ]
    )

    @Test("ordena estancados primero y sin-recorrido al final")
    func order() {
        let rows = Self.three.progressRows(for: ["a", "b", "c"], anchor: "2026-06-19", weeks: 8)
        #expect(rows.map(\.exerciseID) == ["a", "b", "c"])
        #expect(rows.map(\.status) == [.stalled, .progressing, .noTrack])
    }
}

/// Fixture `d` de los tests de computeGroupSets.
private let groupData = TrainingData(
    catalog: Catalog([exercise("remo", "Remo", .espalda), exercise("jalon", "Jalón", .espalda), exercise("curl", "Curl", "brazos"), exercise("raro", "Raro")]),
    routines: [Routine(id: "DIA1", name: "1", exerciseIDs: ["remo"])],
    history: [
        makeSession("2026-06-12", completed: true, logs: [
            makeLog("remo", weight: 30, series: 4, expected: 10, actual: [10]),
            makeLog("curl", weight: 10, series: 3, expected: 10, actual: [10]),
        ]),
        makeSession("2026-06-19", completed: true, logs: [
            makeLog("jalon", weight: 60, series: 4, expected: 10, actual: [10]),
            makeLog("raro", weight: 0, series: 2, expected: 10, actual: [10]),
            makeLog("remo", weight: 30, series: 4, expected: 10, actual: [10], skipped: true),
        ]),
    ]
)

private func one(_ log: ExerciseLog, _ catalog: Catalog, date: LocalDate = "2026-06-19") -> TrainingData {
    TrainingData(catalog: catalog, history: [makeSession(date, completed: true, logs: [log])])
}

@Suite("computeGroupSets")
struct GroupSetsTests {
    @Test("agrupa series por grupo y las divide entre las semanas")
    func groups() {
        let espalda = groupData.groupSets(anchor: "2026-06-19", weeks: 4).first { $0.group == .espalda }
        #expect(espalda?.sets == 8)
        #expect(isClose(espalda?.setsPerWeek ?? 0, 2, digits: 5))
    }

    @Test("ordena de más a menos series")
    func order() { #expect(groupData.groupSets(anchor: "2026-06-19", weeks: 4).first?.group == .espalda) }

    @Test("ignora las sesiones saltadas")
    func skipped() { #expect(groupData.groupSets(anchor: "2026-06-19", weeks: 4).first { $0.group == .espalda }?.sets == 8) }

    @Test("los ejercicios sin grupo caen en (sin grupo)")
    func noGroup() { #expect(groupData.groupSets(anchor: "2026-06-19", weeks: 4).first { $0.group == nil }?.sets == 2) }

    @Test("los tirones suman media serie a bíceps sin tocar su grupo directo")
    func pulls() {
        let data = TrainingData(
            catalog: Catalog([exercise("jalon_al_pecho_neutro", "Jalón neutro", .espalda), exercise("curl_biceps_polea", "Curl polea", .biceps)]),
            history: [makeSession("2026-06-19", completed: true, logs: [
                makeLog("jalon_al_pecho_neutro", weight: 60, series: 4, expected: 10, actual: [10]),
                makeLog("curl_biceps_polea", weight: 20, series: 3, expected: 10, actual: [10]),
            ])]
        )
        let groups = data.groupSets(anchor: "2026-06-19", weeks: 8)
        let espalda = groups.first { $0.group == .espalda }
        let biceps = groups.first { $0.group == .biceps }
        #expect(espalda?.sets == 4)
        #expect(espalda?.indirectSets == 0)
        #expect(biceps?.sets == 3)
        #expect(biceps?.indirectSets == 2)
        #expect(biceps?.totalSets == 5)
        #expect(biceps?.indirect == [IndirectSets(name: "Jalón neutro", sets: 2)])
    }

    @Test("un grupo que solo recibe trabajo indirecto también aparece")
    func onlyIndirect() {
        let data = one(makeLog("press_banca_mancuernas", weight: 30, series: 4, expected: 10, actual: [10]),
                       Catalog([exercise("press_banca_mancuernas", "Press banca", .pecho)]))
        let triceps = data.groupSets(anchor: "2026-06-19", weeks: 8).first { $0.group == .triceps }
        #expect(triceps?.sets == 0)
        #expect(triceps?.indirectSets == 2)
        #expect(triceps?.totalSets == 2)
    }

    @Test("rangoDeVentana escala la franja semanal a la ventana")
    func referenceRange() {
        #expect(GroupSets.referenceRange(weeks: 8) == 32...80)
        #expect(GroupSets.referenceRange(weeks: 4) == 16...40)
    }

    @Test("cada ejercicio trae sus series y sus sesiones")
    func exercises() {
        let espalda = groupData.groupSets(anchor: "2026-06-19", weeks: 4).first { $0.group == .espalda }
        let remo = espalda?.exercises.first { $0.name == "Remo" }
        #expect(remo?.sets == 4)
        #expect(remo?.sessions == 1)
        #expect(espalda?.sessions == 2)
    }

    @Test("desglosa los ejercicios de cada grupo, de más a menos")
    func breakdown() {
        #expect(groupData.groupSets(anchor: "2026-06-19", weeks: 4).first { $0.group == .espalda }?.exercises.map(\.name) == ["Jalón", "Remo"])
    }

    @Test("deja fuera lo anterior a la ventana; el límite es inclusivo")
    func window() {
        var withOld = groupData
        withOld.catalog = Catalog(groupData.catalog.all + [exercise("sentadilla", "Sentadilla", .piernas)])
        withOld.history.insert(makeSession("2026-01-05", completed: true, logs: [makeLog("sentadilla", weight: 80, series: 5, expected: 8, actual: [8])]), at: 0)
        #expect(withOld.groupSets(anchor: "2026-06-19", weeks: 4).first { $0.group == .piernas } == nil)
        // la sesión del 12/06 cae justo en el borde de una ventana de 1 semana
        #expect(withOld.groupSets(anchor: "2026-06-19", weeks: 1).first { $0.group == "brazos" }?.sets == 3)
    }
}

@Suite("los secundarios editados alimentan Progreso")
struct EditedSecondariesTests {
    @Test("computeGroupSets usa los secundarios de la DB por encima del mapa")
    func editedWins() {
        let data = one(makeLog("sentadilla", weight: 100, series: 4, expected: 8, actual: [8]),
                       Catalog([exercise("sentadilla", "Sentadilla", .piernas, secondary: [.core])]), date: "2026-08-20")
        let core = data.groupSets(anchor: "2026-08-25", weeks: 8).first { $0.group == .core }
        #expect(core?.indirectSets == 2)
        #expect(core?.indirect == [IndirectSets(name: "Sentadilla", sets: 2)])
    }

    @Test("secundarios vacíos en la DB anulan el mapa hardcodeado")
    func emptyWins() {
        let data = one(makeLog("jalon_al_pecho", weight: 60, series: 4, expected: 10, actual: [10]),
                       Catalog([exercise("jalon_al_pecho", "Jalón", .espalda, secondary: [])]), date: "2026-08-20")
        #expect(data.groupSets(anchor: "2026-08-25", weeks: 8).first { $0.group == .biceps } == nil)
    }
}

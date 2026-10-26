import Domain
import Testing

// Portados de tests/unit/workout.test.js de la PWA. Los de `setParam`/`setRep`, que reciben el
// texto del campo, están en PresentationTests (el texto se interpreta allí); aquí, los que no.

@Suite("buildWorkoutEntry")
struct BuildWorkoutEntryTests {
    private func build(_ ids: [ExerciseID], _ seeds: [ExerciseID: LogSeed] = [:]) -> Session {
        Session.planned(date: "2026-03-28", routine: "DIA1", exerciseIDs: ids, seed: stubSeeds(seeds))
    }

    @Test("crea entry con fecha, tipo y completed=false")
    func basics() {
        let entry = build([])
        #expect(entry.date == "2026-03-28")
        #expect(entry.routineID == "DIA1")
        #expect(entry.completed == false)
    }

    @Test("carga peso/series/reps del último entreno equivalente")
    func loadsLastValues() {
        let entry = build(["press_banca"], ["press_banca": seed(series: 4, expected: 8, weight: 80, actual: [8, 8, 7, 6])])
        let log = entry.logs[0]
        #expect(log.weight == 80)
        #expect(log.series == 4)
        #expect(log.targetReps == 8)
    }

    @Test("si no hay historial previo, usa defaults (3 series, 10 reps, 0 kg)")
    func defaults() {
        let log = build(["press_banca"]).logs[0]
        #expect(log.weight == 0)
        #expect(log.series == 3)
        #expect(log.targetReps == 10)
    }

    @Test("pre-rellena reps.actual con valores previos (no nulls) hasta el nº de series")
    func prefills() {
        let entry = build(["press_banca"], ["press_banca": seed(series: 3, expected: 10, weight: 60, actual: [10, 8, 9])])
        #expect(entry.logs[0].actualReps == [10, 8, 9])
    }

    @Test("si series actual < series previas, trunca reps.actual")
    func truncates() {
        let entry = build(["press_banca"], ["press_banca": seed(series: 2, expected: 10, weight: 60, actual: [10, 8, 9])])
        #expect(entry.logs[0].actualReps == [10, 8])
    }

    @Test("si series actual > series previas, rellena con repsExpected")
    func pads() {
        let entry = build(["press_banca"], ["press_banca": seed(series: 4, expected: 10, weight: 60, actual: [10, 8])])
        #expect(entry.logs[0].actualReps == [10, 8, 10, 10])
    }

    @Test("con rutina vacía (0 ejercicios), crea entry con logs=[]")
    func emptyRoutine() {
        #expect(build([]).logs == [])
    }

    @Test("ejercicio sin historial previo usa defaults")
    func noHistoryDefaults() {
        // El nombre ya no se copia en el log (se busca en el catálogo por id): se comprueba el id.
        let log = build(["press_banca"]).logs[0]
        #expect(log.exerciseID == "press_banca")
        #expect(log.weight == 0)
        #expect(log.series == 3)
        #expect(log.targetReps == 10)
        #expect(log.actualReps == [10, 10, 10])
    }

    @Test("prevActual con nulls intercalados: copia no-null, null se rellena con expected")
    func nullsReplaced() {
        let entry = build(["press_banca"], ["press_banca": seed(series: 3, expected: 10, weight: 60, actual: [10, nil, 8])])
        #expect(entry.logs[0].actualReps == [10, 10, 8])
    }

    @Test("sin historial previo, reps.actual se pre-rellena con repsExpected (no nulls)")
    func noNulls() {
        let log = build(["press_banca"]).logs[0]
        #expect(log.actualReps == [10, 10, 10])
        #expect(log.actualReps.allSatisfy { $0 != nil })
    }

    @Test("entry recién creado sin historial pasa validación (bug fix: no debe dar campos vacíos)")
    func newEntryValid() {
        #expect(build(["press_banca"]).validation.isValid)
    }

    @Test("entry con historial parcial (más series que antes) también pasa validación")
    func partialHistoryValid() {
        let entry = build(["press_banca"], ["press_banca": seed(series: 5, expected: 8, weight: 60, actual: [8, 7, 6])])
        #expect(entry.logs[0].actualReps == [8, 7, 6, 8, 8])
        #expect(entry.validation.isValid)
    }

    @Test("flujo completo build→validate→finish sin historial funciona sin error")
    func fullFlowNoHistory() {
        var entry = build(["press_banca"])
        #expect(entry.validation.isValid)
        entry.finish()
        #expect(entry.completed)
        #expect(entry.logs[0].actualReps == [10, 10, 10])
    }

    @Test("flujo completo build→validate→finish con historial funciona sin error")
    func fullFlowWithHistory() {
        var entry = build(["press_banca"], ["press_banca": seed(series: 3, expected: 10, weight: 60, actual: [10, 8, 9])])
        #expect(entry.validation.isValid)
        entry.finish()
        #expect(entry.completed)
        #expect(entry.logs[0].actualReps == [10, 8, 9])
    }

    @Test("múltiples ejercicios sin historial todos pasan validación")
    func manyValid() {
        let entry = build(["press_banca", "sentadilla", "curl_biceps"])
        #expect(entry.validation.isValid)
        #expect(entry.logs.count == 3)
        for log in entry.logs {
            #expect(log.actualReps.allSatisfy { $0 != nil })
        }
    }
}

@Suite("buildLog")
struct BuildLogTests {
    @Test("devuelve log con shape correcto a partir de last")
    func shape() {
        let log = ExerciseLog(planning: "press_banca", from: seed(series: 3, expected: 10, weight: 50, actual: [10, 9, 8]))
        #expect(log == ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 9, 8], weight: 50))
    }

    @Test("sin historial (repsActual vacío) prerellena actual con repsExpected")
    func emptyPrevious() {
        let log = ExerciseLog(planning: "press_banca", from: seed(series: 3, expected: 10, weight: 0, actual: []))
        #expect(log.actualReps == [10, 10, 10])
        #expect(log.actualReps.allSatisfy { $0 != nil })
    }

    @Test("prevActual más corto que series rellena la cola con repsExpected")
    func shorter() {
        let log = ExerciseLog(planning: "press_banca", from: seed(series: 4, expected: 8, weight: 60, actual: [8, 7]))
        #expect(log.actualReps == [8, 7, 8, 8])
    }

    @Test("prevActual más largo que series trunca")
    func longer() {
        let log = ExerciseLog(planning: "press_banca", from: seed(series: 2, expected: 10, weight: 60, actual: [10, 9, 8]))
        #expect(log.actualReps == [10, 9])
    }

    @Test("prevActual con nulls intercalados los reemplaza por repsExpected")
    func nulls() {
        let log = ExerciseLog(planning: "press_banca", from: seed(series: 3, expected: 10, weight: 60, actual: [10, nil, 8]))
        #expect(log.actualReps == [10, 10, 8])
    }

    @Test("repsActual undefined se trata como []")
    func undefinedActual() {
        // En Swift no hay `undefined`: un `LogSeed` sin reps tiene la lista vacía.
        let log = ExerciseLog(planning: "curl", from: LogSeed(series: 2, targetReps: 12, weight: 15))
        #expect(log.actualReps == [12, 12])
    }

    @Test("log producido pasa validación")
    func valid() {
        let log = ExerciseLog(planning: "press_banca", from: seed(series: 3, expected: 10, weight: 0, actual: []))
        #expect(log.validationErrors == [])
    }
}

@Suite("finishWorkoutEntry")
struct FinishWorkoutEntryTests {
    @Test("marca completed=true")
    func marksCompleted() {
        var entry = makeSession(logs: [makeLog()])
        entry.finish()
        #expect(entry.completed)
    }

    @Test("no modifica reps que ya tenían valor")
    func keepsReps() {
        var entry = makeSession(logs: [makeLog(expected: 10, actual: [8, 7, 9])])
        entry.finish()
        #expect(entry.logs[0].actualReps == [8, 7, 9])
    }

    @Test("con todas las reps ya completadas, no cambia nada")
    func nothingChanges() {
        var entry = makeSession(logs: [makeLog(expected: 10, actual: [10, 10, 10])])
        entry.finish()
        #expect(entry.logs[0].actualReps == [10, 10, 10])
    }
}

@Suite("adjustParam — weight")
struct AdjustWeightTests {
    @Test("incrementa peso en +delta")
    func increments() {
        var log = makeLog(weight: 50)
        log.adjust(.weight, by: 2.5)
        #expect(log.weight == 52.5)
    }

    @Test("decrementa peso en -delta")
    func decrements() {
        var log = makeLog(weight: 50)
        log.adjust(.weight, by: -2.5)
        #expect(log.weight == 47.5)
    }

    @Test("peso no baja de 0 (clamp)")
    func clamps() {
        var log = makeLog(weight: 1)
        log.adjust(.weight, by: -5)
        #expect(log.weight == 0)
    }

    @Test("redondea a 1 decimal (evita floating point)")
    func rounds() {
        var log = makeLog(weight: 50)
        log.adjust(.weight, by: 2.5)
        log.adjust(.weight, by: 2.5)
        #expect(log.weight == 55)
        var log2 = makeLog(weight: 0.1)
        log2.adjust(.weight, by: 0.2)
        #expect(log2.weight == 0.3)
    }
}

@Suite("weightStep")
struct WeightStepTests {
    @Test("peso < 20 → escalon de 1kg")
    func light() {
        #expect(ExerciseLog.weightStep(for: 0) == 1)
        #expect(ExerciseLog.weightStep(for: 10) == 1)
        #expect(ExerciseLog.weightStep(for: 19.5) == 1)
    }

    @Test("20 <= peso < 50 → escalon de 2kg")
    func medium() {
        #expect(ExerciseLog.weightStep(for: 20) == 2)
        #expect(ExerciseLog.weightStep(for: 35) == 2)
        #expect(ExerciseLog.weightStep(for: 49.5) == 2)
    }

    @Test("peso >= 50 → escalon de 5kg")
    func heavy() {
        #expect(ExerciseLog.weightStep(for: 50) == 5)
        #expect(ExerciseLog.weightStep(for: 100) == 5)
    }
}

@Suite("adjustParam — series")
struct AdjustSeriesTests {
    @Test("incrementa series en +1")
    func increments() {
        var log = makeLog(series: 3)
        log.adjust(.series, by: 1)
        #expect(log.series == 4)
    }

    @Test("decrementa series en -1")
    func decrements() {
        var log = makeLog(series: 3)
        log.adjust(.series, by: -1)
        #expect(log.series == 2)
    }

    @Test("series no baja de 1")
    func clamps() {
        var log = makeLog(series: 1)
        log.adjust(.series, by: -1)
        #expect(log.series == 1)
    }

    @Test("al incrementar, añade reps.expected a reps.actual")
    func appends() {
        var log = makeLog(series: 2, expected: 10, actual: [10, 8])
        log.adjust(.series, by: 1)
        #expect(log.actualReps == [10, 8, 10])
    }

    @Test("al decrementar, elimina último de reps.actual")
    func removesLast() {
        var log = makeLog(series: 3, actual: [10, 8, 9])
        log.adjust(.series, by: -1)
        #expect(log.actualReps == [10, 8])
    }
}

@Suite("adjustParam — repsExpected")
struct AdjustTargetRepsTests {
    @Test("incrementa reps esperadas en +1")
    func increments() {
        var log = makeLog(expected: 10)
        log.adjust(.targetReps, by: 1)
        #expect(log.targetReps == 11)
    }

    @Test("decrementa reps esperadas en -1")
    func decrements() {
        var log = makeLog(expected: 10)
        log.adjust(.targetReps, by: -1)
        #expect(log.targetReps == 9)
    }

    @Test("reps esperadas no bajan de 1")
    func clamps() {
        var log = makeLog(expected: 1)
        log.adjust(.targetReps, by: -1)
        #expect(log.targetReps == 1)
    }

    @Test("sincroniza todas las reps actuales al nuevo expected (actuales con valores)")
    func syncsUp() {
        var log = makeLog(series: 3, expected: 11, actual: [11, 11, 9])
        log.adjust(.targetReps, by: 1)
        #expect(log.targetReps == 12)
        #expect(log.actualReps == [12, 12, 12])
    }

    @Test("sincroniza todas las reps actuales al bajar expected")
    func syncsDown() {
        var log = makeLog(series: 3, expected: 11, actual: [11, 11, 9])
        log.adjust(.targetReps, by: -3)
        #expect(log.targetReps == 8)
        #expect(log.actualReps == [8, 8, 8])
    }

    @Test("sincroniza reps actuales que eran null")
    func syncsNulls() {
        var log = makeLog(series: 3, expected: 10, actual: [nil, nil, nil])
        log.adjust(.targetReps, by: 1)
        #expect(log.actualReps == [11, 11, 11])
    }

    @Test("sincroniza reps actuales mixtas (con valores y nulls)")
    func syncsMixed() {
        var log = makeLog(series: 3, expected: 10, actual: [10, nil, 8])
        log.adjust(.targetReps, by: 2)
        #expect(log.actualReps == [12, 12, 12])
    }

    @Test("al llegar al clamp (1), reps actuales también se ponen a 1")
    func clampSyncs() {
        var log = makeLog(series: 3, expected: 1, actual: [1, 1, 1])
        log.adjust(.targetReps, by: -1)
        #expect(log.targetReps == 1)
        #expect(log.actualReps == [1, 1, 1])
    }

    @Test("cambiar weight NO toca reps.actual")
    func weightKeepsReps() {
        var log = makeLog(weight: 50, series: 3, expected: 10, actual: [11, 9, 10])
        log.adjust(.weight, by: 5)
        #expect(log.actualReps == [11, 9, 10])
    }

    @Test("cambiar series NO sincroniza reps.actual al expected (añade reps.expected)")
    func seriesKeepsReps() {
        var log = makeLog(series: 3, expected: 10, actual: [11, 9, 10])
        log.adjust(.series, by: 1)
        #expect(log.actualReps == [11, 9, 10, 10])
    }
}

@Suite("adjustRep")
struct AdjustRepTests {
    @Test("incrementa rep de una serie específica")
    func increments() {
        var log = makeLog(expected: 10, actual: [10, 8, 9])
        log.adjustRep(at: 1, by: 1)
        #expect(log.actualReps[1] == 9)
    }

    @Test("decrementa rep de una serie específica")
    func decrements() {
        var log = makeLog(expected: 10, actual: [10, 8, 9])
        log.adjustRep(at: 1, by: -1)
        #expect(log.actualReps[1] == 7)
    }

    @Test("si rep era null, usa expected como base y aplica delta")
    func fromTarget() {
        var log = makeLog(expected: 10, actual: [nil, nil, nil])
        log.adjustRep(at: 0, by: 1)
        #expect(log.actualReps[0] == 11)
    }

    @Test("rep no baja de 0")
    func clamps() {
        var log = makeLog(expected: 10, actual: [0, 8, 9])
        log.adjustRep(at: 0, by: -1)
        #expect(log.actualReps[0] == 0)
    }
}

@Suite("setRep")
struct SetRepTests {
    // Los casos con texto ("", "abc", "12") están en PresentationTests; aquí, el valor ya leído.
    @Test("valor 0 → acepta (0 reps completadas)")
    func zero() {
        var log = makeLog(expected: 10, actual: [10, 8, 9])
        log.setRep(at: 1, to: 0)
        #expect(log.actualReps[1] == 0)
    }

    @Test("valor negativo → clamp a 0")
    func negative() {
        var log = makeLog(expected: 10, actual: [10, 8, 9])
        log.setRep(at: 1, to: -5)
        #expect(log.actualReps[1] == 0)
    }
}

@Suite("objetivo sigue al máximo de reps reales")
struct TargetFollowsMaxTests {
    @Test("setRep: subir una real por encima del objetivo sube el objetivo")
    func setRaises() {
        var log = makeLog(expected: 12, actual: [12, 12, 12])
        log.setRep(at: 1, to: 13)
        #expect(log.actualReps == [12, 13, 12])
        #expect(log.targetReps == 13)
    }

    @Test("setRep: bajar el máximo baja el objetivo")
    func setLowers() {
        var log = makeLog(expected: 12, actual: [11, 12, 11])
        log.setRep(at: 1, to: 11)
        #expect(log.actualReps == [11, 11, 11])
        #expect(log.targetReps == 11)
    }

    @Test("setRep: editar real sin tocar el máximo deja el objetivo igual")
    func setKeeps() {
        var log = makeLog(expected: 11, actual: [11, 11, 11])
        log.setRep(at: 0, to: 10)
        #expect(log.actualReps == [10, 11, 11])
        #expect(log.targetReps == 11)
    }

    @Test("setRep: ignora nulls al calcular el máximo")
    func setIgnoresNulls() {
        var log = makeLog(expected: 10, actual: [10, nil, 10])
        log.setRep(at: 0, to: 13)
        #expect(log.targetReps == 13)
    }

    @Test("setRep: si todas las reales quedan null, objetivo no cambia")
    func setAllNull() {
        var log = makeLog(series: 1, expected: 12, actual: [12])
        log.setRep(at: 0, to: nil)
        #expect(log.actualReps == [nil])
        #expect(log.targetReps == 12)
    }

    @Test("setRep: máximo 0 → objetivo clamp a 1")
    func setZeroMax() {
        var log = makeLog(expected: 2, actual: [0, 0, 2])
        log.setRep(at: 2, to: 0)
        #expect(log.actualReps == [0, 0, 0])
        #expect(log.targetReps == 1)
    }

    @Test("adjustRep: subir real por encima del objetivo sube el objetivo")
    func adjustRaises() {
        var log = makeLog(expected: 12, actual: [12, 12, 12])
        log.adjustRep(at: 0, by: 1)
        #expect(log.actualReps == [13, 12, 12])
        #expect(log.targetReps == 13)
    }

    @Test("adjustRep: bajar el máximo baja el objetivo")
    func adjustLowers() {
        var log = makeLog(expected: 12, actual: [12, 11, 11])
        log.adjustRep(at: 0, by: -1)
        #expect(log.actualReps == [11, 11, 11])
        #expect(log.targetReps == 11)
    }
}

@Suite("detectRecords")
struct DetectRecordsTests {
    private func historyEntry(_ weight: Double, _ series: Int, _ actual: [Int?], date: LocalDate = "2026-03-01") -> Session {
        makeSession(date, completed: true, logs: [makeLog("press_banca", weight: weight, series: series, expected: 10, actual: actual)])
    }

    @Test("detecta nuevo PR de volumen cuando supera máximo histórico")
    func volumeRecord() {
        let previous = [historyEntry(50, 3, [10, 10, 10])]
        let log = makeLog("press_banca", weight: 60, series: 3, actual: [10, 10, 10])
        #expect(log.records(against: previous).isVolumeRecord)
    }

    @Test("detecta nuevo PR de e1RM cuando supera máximo histórico")
    func e1rmRecord() {
        let previous = [historyEntry(80, 3, [6, 6, 6])]
        let log = makeLog("press_banca", weight: 100, series: 3, actual: [6, 6, 6])
        #expect(log.records(against: previous).isE1RMRecord)
    }

    @Test("NO detecta PR si ninguna rep está completada (todas null)")
    func noRepsNoRecord() {
        let previous = [historyEntry(50, 3, [10, 10, 10])]
        let records = makeLog("press_banca", weight: 100, series: 3, actual: [nil, nil, nil]).records(against: previous)
        #expect(!records.isVolumeRecord)
        #expect(!records.isE1RMRecord)
    }

    @Test("NO detecta PR si volumen/e1RM es 0")
    func zeroNoRecord() {
        let records = makeLog("press_banca", weight: 0, series: 3, actual: [nil, nil, nil]).records(against: [])
        #expect(!records.isVolumeRecord)
        #expect(!records.isE1RMRecord)
    }

    @Test("NO detecta PR si es igual al máximo (solo si supera estrictamente)")
    func equalNoRecord() {
        let previous = [historyEntry(50, 3, [10, 10, 10])]
        let records = makeLog("press_banca", weight: 50, series: 3, actual: [10, 10, 10]).records(against: previous)
        #expect(!records.isVolumeRecord)
        #expect(!records.isE1RMRecord)
    }

    @Test("sin historial previo y volumen > 0 → sí es PR (primer registro)")
    func firstRecord() {
        let records = makeLog("press_banca", weight: 50, series: 3, actual: [10, 10, 10]).records(against: [])
        #expect(records.isVolumeRecord)
        #expect(records.isE1RMRecord)
    }

    @Test("ejercicio con peso 0 (bodyweight): puede tener PR de volumen pero no de e1RM")
    func bodyweight() {
        let previous = [historyEntry(0, 3, [10, 10, 10])]
        let records = makeLog("press_banca", weight: 0, series: 4, actual: [10, 10, 10, 10]).records(against: previous)
        #expect(records.isVolumeRecord)
        #expect(!records.isE1RMRecord)
    }

    @Test("excluye correctamente otros ejercicios del historial")
    func otherExercises() {
        let other = makeSession("2026-03-01", completed: true, logs: [makeLog("sentadilla", weight: 200, series: 5, expected: 5, actual: [5, 5, 5, 5, 5])])
        let log = makeLog("press_banca", weight: 50, series: 3, actual: [10, 10, 10])
        #expect(log.records(against: [other]).isVolumeRecord)
    }
}

@Suite("validateLog")
struct ValidateLogTests {
    @Test("log válido completo → sin errores")
    func valid() {
        #expect(makeLog(weight: 50, series: 3, expected: 10, actual: [10, 8, 9]).validationErrors == [])
    }

    @Test("weight negativo → error en field weight")
    func negativeWeight() {
        #expect(makeLog(weight: -5, series: 3, expected: 10, actual: [10, 8, 9]).validationErrors == [.negativeWeight])
    }

    @Test("weight 0 → sin error (bodyweight)")
    func zeroWeight() {
        #expect(!makeLog(weight: 0, series: 3, expected: 10, actual: [10, 8, 9]).validationErrors.contains(.negativeWeight))
    }

    @Test("series 0 → error en field series")
    func zeroSeries() {
        var log = makeLog(weight: 50, series: 1, expected: 10, actual: [10])
        log.series = 0
        #expect(log.validationErrors.contains(.invalidSeries))
    }

    @Test("repsExpected 0 → error en field repsExpected")
    func zeroTarget() {
        var log = makeLog(weight: 50, series: 3, expected: 10, actual: [10, 8, 9])
        log.targetReps = 0
        #expect(log.validationErrors.contains(.invalidTargetReps))
    }

    @Test("rep null en serie 0 → error con field rep, index 0")
    func nullRep() {
        #expect(makeLog(weight: 50, series: 3, expected: 10, actual: [nil, 8, 9]).validationErrors == [.missingRep(index: 0)])
    }

    @Test("rep negativo → error con field rep")
    func negativeRep() {
        #expect(makeLog(weight: 50, series: 3, expected: 10, actual: [10, -1, 9]).validationErrors.contains(.invalidRep(index: 1)))
    }

    @Test("todas las reps completadas → sin errores en reps")
    func allReps() {
        #expect(makeLog(weight: 50, series: 3, expected: 10, actual: [10, 8, 9]).validationErrors.allSatisfy { $0.repIndex == nil })
    }

    @Test("mezcla de reps válidas y null → errores solo en las null")
    func mixed() {
        let errors = makeLog(weight: 50, series: 4, expected: 10, actual: [10, nil, 8, nil]).validationErrors
        #expect(errors.compactMap(\.repIndex) == [1, 3])
    }

    @Test("rep undefined → error no completada")
    func undefinedRep() {
        // En JS, `actual[i]` fuera de la lista es `undefined`; aquí, una lista más corta que las series.
        #expect(makeLog(weight: 50, series: 3, expected: 10, actual: [10]).validationErrors == [.missingRep(index: 1), .missingRep(index: 2)])
    }

    @Test("rep 0 → válido (0 reps completadas)")
    func zeroReps() {
        #expect(makeLog(weight: 50, series: 3, expected: 10, actual: [0, 0, 0]).validationErrors == [])
    }
}

@Suite("validateEntry")
struct ValidateEntryTests {
    @Test("entry con todos los logs válidos → valid: true")
    func allValid() {
        let entry = makeSession(logs: [
            makeLog(weight: 50, series: 3, expected: 10, actual: [10, 8, 9]),
            makeLog("sentadilla", weight: 80, series: 3, expected: 8, actual: [8, 7, 6]),
        ])
        #expect(entry.validation.isValid)
        #expect(entry.validation.errorsByLog.isEmpty)
    }

    @Test("entry con un log inválido → valid: false, errorsByLog tiene ese logIdx")
    func oneInvalid() {
        let entry = makeSession(logs: [
            makeLog(weight: 50, series: 3, expected: 10, actual: [10, 8, 9]),
            makeLog("sentadilla", weight: 80, series: 3, expected: 8, actual: [nil, 7, 6]),
        ])
        #expect(!entry.validation.isValid)
        #expect(entry.validation.errorsByLog[1] != nil)
        #expect(entry.validation.errorsByLog[0] == nil)
    }

    @Test("entry con múltiples logs inválidos → todos aparecen en errorsByLog")
    func manyInvalid() {
        let entry = makeSession(logs: [
            makeLog(weight: -5, series: 3, expected: 10, actual: [10, 8, 9]),
            makeLog("sentadilla", weight: 80, series: 3, expected: 8, actual: [8, 7, 6]),
            makeLog("curl", weight: 20, series: 3, expected: 10, actual: [nil, nil, nil]),
        ])
        let validation = entry.validation
        #expect(!validation.isValid)
        #expect(validation.errorsByLog[0] != nil)
        #expect(validation.errorsByLog[1] == nil)
        #expect(validation.errorsByLog[2] != nil)
    }

    @Test("entry sin logs → valid: true")
    func empty() {
        #expect(makeSession(logs: []).validation.isValid)
    }
}

@Suite("adjustParam — casos borde")
struct AdjustEdgeCaseTests {
    @Test("delta 0 en weight no cambia nada")
    func zeroWeight() {
        var log = makeLog(weight: 50)
        log.adjust(.weight, by: 0)
        #expect(log.weight == 50)
    }

    @Test("delta 0 en series no cambia nada")
    func zeroSeries() {
        var log = makeLog(series: 3, actual: [10, 8, 9])
        log.adjust(.series, by: 0)
        #expect(log.series == 3)
        #expect(log.actualReps == [10, 8, 9])
    }

    @Test("decrementar y volver a incrementar series → nuevo slot usa reps.expected actual")
    func downUp() {
        var log = makeLog(series: 3, expected: 12, actual: [12, 12, 12])
        log.adjust(.series, by: -1)
        log.adjust(.series, by: 1)
        #expect(log.actualReps[2] == 12)
    }

    @Test("bajar series con reps.actual vacío no falla")
    func decrementEmpty() {
        // En JS `pop()` de una lista vacía no hace nada; en Swift, `removeLast()` se cuelga.
        var log = makeLog(series: 3, actual: [])
        log.adjust(.series, by: -1)
        #expect(log.series == 2)
        #expect(log.actualReps == [])
    }

    @Test("sincronizar repsExpected con 1 sola serie")
    func singleSeries() {
        var log = makeLog(series: 1, expected: 8, actual: [6])
        log.adjust(.targetReps, by: 1)
        #expect(log.targetReps == 9)
        #expect(log.actualReps == [9])
    }
}

@Suite("adjustRep — casos borde")
struct AdjustRepEdgeCaseTests {
    @Test("delta 0 con rep null → parte del expected")
    func zeroDelta() {
        var log = makeLog(expected: 12, actual: [nil, nil, nil])
        log.adjustRep(at: 0, by: 0)
        #expect(log.actualReps[0] == 12)
    }

    @Test("reps.actual array vacío → parte del expected")
    func emptyActual() {
        var log = makeLog(series: 3, expected: 10, actual: [])
        log.adjustRep(at: 0, by: 1)
        #expect(log.actualReps[0] == 11)
    }

    @Test("reps.actual con menos elementos que series → parte del expected")
    func shortActual() {
        var log = makeLog(series: 3, expected: 8, actual: [10])
        log.adjustRep(at: 2, by: -1)
        #expect(log.actualReps[2] == 7)
    }
}

@Suite("swapLogExercise")
struct SwapLogExerciseTests {
    private let lastB = seed(series: 3, expected: 10, weight: 0)

    private func makeSwapEntry(completed: Bool = false, logs: [ExerciseLog]? = nil) -> Session {
        makeSession("2026-04-29", completed: completed, logs: logs ?? [makeLog("press_banca"), makeLog("curl_biceps")])
    }

    @Test("1 — swap normal A→B: exercise_id=B, swappedFrom=A")
    func normal() throws {
        var entry = makeSwapEntry()
        try entry.swapExercise(at: 0, to: "sentadilla", seed: lastB)
        #expect(entry.logs[0].exerciseID == "sentadilla")
        #expect(entry.logs[0].swappedFrom == "press_banca")
    }

    @Test("2 — doble swap A→B→C: swappedFrom queda en A (no en B)")
    func double() throws {
        var entry = makeSwapEntry()
        try entry.swapExercise(at: 0, to: "sentadilla", seed: lastB)
        try entry.swapExercise(at: 0, to: "dominadas", seed: lastB)
        #expect(entry.logs[0].exerciseID == "dominadas")
        #expect(entry.logs[0].swappedFrom == "press_banca")
    }

    @Test("3 — swap de vuelta al original A→B→A: sin swappedFrom")
    func back() throws {
        var entry = makeSwapEntry()
        try entry.swapExercise(at: 0, to: "sentadilla", seed: lastB)
        try entry.swapExercise(at: 0, to: "press_banca", seed: lastB)
        #expect(entry.logs[0].exerciseID == "press_banca")
        #expect(entry.logs[0].swappedFrom == nil)
    }

    @Test("4 — ejercicio ya presente en otro log → duplicate, entry intacto")
    func duplicate() {
        var entry = makeSwapEntry()
        let before = entry
        #expect(throws: SwapError.duplicate) { try entry.swapExercise(at: 0, to: "curl_biceps", seed: lastB) }
        #expect(entry == before)
    }

    @Test("5 — mismo exercise_id → same, entry intacto")
    func same() {
        var entry = makeSwapEntry()
        let before = entry
        #expect(throws: SwapError.same) { try entry.swapExercise(at: 0, to: "press_banca", seed: lastB) }
        #expect(entry == before)
    }

    @Test("6 — entry completed → not_active, entry intacto")
    func notActive() {
        var entry = makeSwapEntry(completed: true)
        let before = entry
        #expect(throws: SwapError.notActive) { try entry.swapExercise(at: 0, to: "sentadilla", seed: lastB) }
        #expect(entry == before)
    }

    @Test("7 — logIdx fuera de rango → not_found")
    func notFound() {
        var entry = makeSwapEntry()
        #expect(throws: SwapError.notFound) { try entry.swapExercise(at: -1, to: "sentadilla", seed: lastB) }
        #expect(throws: SwapError.notFound) { try entry.swapExercise(at: 99, to: "sentadilla", seed: lastB) }
    }

    @Test("8 — nuevo log usa series/repsExpected/weight de last")
    func usesSeed() throws {
        var entry = makeSwapEntry()
        try entry.swapExercise(at: 0, to: "sentadilla", seed: seed(series: 4, expected: 8, weight: 60, actual: [8, 7, 8, 8]))
        let log = entry.logs[0]
        #expect(log.series == 4)
        #expect(log.targetReps == 8)
        #expect(log.weight == 60)
    }

    @Test("9 — preserva logs vecinos (incluso con swappedFrom propio)")
    func neighbours() throws {
        var entry = makeSwapEntry(logs: [makeLog("a"), makeLog("b"), makeLog("c"), makeLog("d")])
        entry.logs[0].swappedFrom = "z"
        let (log0, log2, log3) = (entry.logs[0], entry.logs[2], entry.logs[3])
        try entry.swapExercise(at: 1, to: "sentadilla", seed: lastB)
        #expect(entry.logs[0] == log0)
        #expect(entry.logs[2] == log2)
        #expect(entry.logs[3] == log3)
    }

    @Test("11 — swap de un log puntual: el nuevo log sigue siendo puntual")
    func oneOffInherited() throws {
        var entry = makeSwapEntry()
        entry.logs[0].oneOff = true
        try entry.swapExercise(at: 0, to: "sentadilla", seed: lastB)
        #expect(entry.logs[0].oneOff)
    }

    @Test("12 — swap de un log normal no inventa oneOff")
    func noOneOff() throws {
        var entry = makeSwapEntry()
        try entry.swapExercise(at: 0, to: "sentadilla", seed: lastB)
        #expect(!entry.logs[0].oneOff)
    }

    @Test("devuelve el log nuevo")
    func returnsNewLog() throws {
        var entry = makeSwapEntry()
        let log = try entry.swapExercise(at: 0, to: "sentadilla", seed: lastB)
        #expect(log == entry.logs[0])
    }
}

@Suite("toggleSkip")
struct ToggleSkipTests {
    @Test("alterna skipped y devuelve el nuevo estado")
    func toggles() {
        var log = makeLog(weight: 80, series: 3, expected: 8, actual: [8, 8, 8])
        #expect(log.toggleSkip() == true)
        #expect(log.skipped)
        #expect(log.toggleSkip() == false)
        #expect(!log.skipped)
    }

    @Test("no destruye los datos del log al alternar")
    func keepsData() {
        var log = makeLog(weight: 80, series: 3, expected: 8, actual: [8, 7, 6])
        log.toggleSkip()
        #expect(log.actualReps == [8, 7, 6])
        #expect(log.weight == 80)
    }
}

@Suite("validateEntry con saltados")
struct ValidateEntrySkippedTests {
    @Test("no valida un log saltado aunque tenga reps vacías")
    func skipsSkipped() {
        let entry = makeSession("2026-06-20", logs: [makeLog("a", weight: 0, series: 3, expected: 8, actual: [nil, nil, nil], skipped: true)])
        #expect(entry.validation.isValid)
    }

    @Test("sí valida los logs no saltados del mismo entry")
    func validatesOthers() {
        let entry = makeSession("2026-06-20", logs: [
            makeLog("a", weight: 0, series: 3, expected: 8, actual: [nil, nil, nil], skipped: true),
            makeLog("b", weight: 0, series: 3, expected: 8, actual: [nil, nil, nil]),
        ])
        let validation = entry.validation
        #expect(!validation.isValid)
        #expect(validation.errorsByLog[1] != nil)
        #expect(validation.errorsByLog[0] == nil)
    }
}

@Suite("findReciprocalSwapTarget")
struct FindReciprocalSwapTargetTests {
    private let routines = [
        Routine(id: "DIA1", name: "1", exerciseIDs: ["press_banca", "curl_biceps"]),
        Routine(id: "DIA2", name: "2", exerciseIDs: ["sentadilla"]),
        Routine(id: "DIA3", name: "3", exerciseIDs: ["press_banca", "sentadilla"]),
    ]

    @Test("1 — match único en otro día → devuelve ese dayType")
    func unique() {
        #expect(routines.reciprocalSwapTarget(from: "DIA2", for: "curl_biceps") == "DIA1")
    }

    @Test("2 — ningún otro día lo tiene → null")
    func none() {
        #expect(routines.reciprocalSwapTarget(from: "DIA1", for: "ejercicio_nuevo") == nil)
    }

    @Test("3 — aparece en 2+ días distintos (ambiguo) → null")
    func ambiguous() {
        #expect(routines.reciprocalSwapTarget(from: "DIA1", for: "sentadilla") == nil)
    }

    @Test("4 — el ejercicio está solo en el propio currentDayType → null (no cuenta el propio día)")
    func ownDayIgnored() {
        #expect(routines.reciprocalSwapTarget(from: "DIA1", for: "press_banca") == "DIA3")
        #expect(routines.reciprocalSwapTarget(from: "DIA3", for: "curl_biceps") == "DIA1")
    }
}

@Suite("Rutinas que llevan un ejercicio")
struct RoutinesContainingTests {
    private let routines = [
        Routine(id: "DIA1", name: "1", exerciseIDs: ["press_banca", "curl_biceps"]),
        Routine(id: "DIA2", name: "2", exerciseIDs: ["sentadilla"]),
        Routine(id: "DIA3", name: "3", exerciseIDs: ["press_banca", "sentadilla"]),
    ]

    @Test("las demás que lo llevan, en su orden, sin contar la propia")
    func others() {
        #expect(routines.others(than: "DIA1", containing: "sentadilla").map(\.id) == ["DIA2", "DIA3"])
        #expect(routines.others(than: "DIA1", containing: "press_banca").map(\.id) == ["DIA3"])
        #expect(routines.others(than: "DIA1", containing: "curl_biceps").isEmpty)
    }

    @Test("sin rutina propia, todas las que lo llevan")
    func withoutOwn() {
        #expect(routines.others(than: nil, containing: "press_banca").map(\.id) == ["DIA1", "DIA3"])
    }
}

@Suite("buildPendingSwap")
struct BuildPendingSwapTests {
    @Test("1 — caso normal → construye el objeto pendiente")
    func normal() {
        let swap = PendingSwap.make(from: "curl_biceps", to: "sentadilla", targetRoutine: ["press_banca", "curl_biceps"], weekStart: "2026-07-13")
        #expect(swap == PendingSwap(from: "curl_biceps", to: "sentadilla", weekStart: "2026-07-13"))
    }

    @Test("2 — toExerciseId ya presente en la rutina destino → null (evita duplicado)")
    func duplicate() {
        #expect(PendingSwap.make(from: "curl_biceps", to: "press_banca", targetRoutine: ["press_banca", "curl_biceps"], weekStart: "2026-07-13") == nil)
    }
}

@Suite("consumePendingSwap")
struct ConsumePendingSwapTests {
    private let routineIDs: [ExerciseID] = ["press_banca", "curl_biceps", "ejercicio_sin_historial"]

    @Test("1 — sin pendiente → routineIds intacto, clearNow false")
    func noPending() {
        #expect(PendingSwap.consume(nil, in: routineIDs, weekStart: "2026-07-13") == SwapConsumption(exerciseIDs: routineIDs, clearNow: false))
    }

    @Test("2 — semana coincide y ejercicio presente → sustituye y NO limpia")
    func applies() {
        let pending = PendingSwap(from: "curl_biceps", to: "sentadilla", weekStart: "2026-07-13")
        let result = PendingSwap.consume(pending, in: routineIDs, weekStart: "2026-07-13")
        #expect(result.clearNow == false)
        #expect(result.exerciseIDs == ["press_banca", "sentadilla", "ejercicio_sin_historial"])
        #expect(routineIDs == ["press_banca", "curl_biceps", "ejercicio_sin_historial"])
    }

    @Test("3 — semana caducada → no sustituye, clearNow true")
    func expired() {
        let pending = PendingSwap(from: "curl_biceps", to: "sentadilla", weekStart: "2026-06-01")
        #expect(PendingSwap.consume(pending, in: routineIDs, weekStart: "2026-07-13") == SwapConsumption(exerciseIDs: routineIDs, clearNow: true))
    }

    @Test("4 — ejercicio ya no está en la rutina destino → no sustituye, clearNow true")
    func missing() {
        let pending = PendingSwap(from: "ya_no_existe", to: "sentadilla", weekStart: "2026-07-13")
        #expect(PendingSwap.consume(pending, in: routineIDs, weekStart: "2026-07-13") == SwapConsumption(exerciseIDs: routineIDs, clearNow: true))
    }

    @Test("5 — reaplicar dos veces seguidas sin borrar el pendiente da la misma sustitución (reinicio mismo día)")
    func idempotent() {
        let pending = PendingSwap(from: "curl_biceps", to: "sentadilla", weekStart: "2026-07-13")
        let first = PendingSwap.consume(pending, in: routineIDs, weekStart: "2026-07-13")
        let second = PendingSwap.consume(pending, in: routineIDs, weekStart: "2026-07-13")
        #expect(first.exerciseIDs == second.exerciseIDs)
        #expect(first.clearNow == false)
        #expect(second.clearNow == false)
    }
}

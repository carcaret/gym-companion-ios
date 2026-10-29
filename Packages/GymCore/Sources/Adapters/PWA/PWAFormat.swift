import Domain
import Foundation

/// Por qué un `db.json` no se puede importar.
public enum PWAFormatError: Error, Hashable {
    /// Le falta `exercises` o `history` (lo mismo que comprueba `isValidRemoteDB` en la PWA).
    case missingKey(String)
    case invalidDate(String)
}

/// Traducción entre el `db.json` de la PWA y el modelo de la app.
public enum PWAFormat {
    /// Lee un `db.json`. Lo que falta en las DB viejas toma su valor de entonces: sin `routines`,
    /// las tres de siempre vacías; sin `pendingSwaps`, ninguno; sin `completed`, terminada; sin
    /// `reps.actual`, ninguna serie. Un ejercicio del historial que ya no está en el catálogo
    /// entra en él con el nombre que traía el log, para no perderlo.
    public static func trainingData(from json: Data) throws -> TrainingData {
        let database = try JSONDecoder().decode(PWADatabase.self, from: json)
        guard let exercises = database.exercises else { throw PWAFormatError.missingKey("exercises") }
        guard let history = database.history else { throw PWAFormatError.missingKey("history") }

        var catalog = exercises.map { id, exercise in
            Exercise(id: ExerciseID(id), name: exercise.name ?? id, group: exercise.grupo.flatMap { $0.isEmpty ? nil : MuscleGroup($0) },
                     secondaryGroups: exercise.secundarios?.map { MuscleGroup($0) })
        }
        var known = Set(exercises.keys)
        for log in history.flatMap(\.logs) where known.insert(log.exercise_id).inserted {
            catalog.append(Exercise(id: ExerciseID(log.exercise_id), name: log.name ?? log.exercise_id))
        }

        return TrainingData(
            catalog: Catalog(catalog),
            routines: routines(database.routines),
            pendingSwaps: try pendingSwaps(database.pendingSwaps ?? [:]),
            history: try history.map(session)
        )
    }

    /// Las de siempre (DIA1–DIA3) primero y con su nombre; las demás detrás, por id y con el id
    /// por nombre (en `db.json` las rutinas no tienen nombre).
    private static func routines(_ routines: [String: [String]]?) -> [Routine] {
        guard let routines else { return Routine.defaults }
        let defaults = Routine.defaults.filter { routines[$0.id.rawValue] != nil }.map { routine in
            Routine(id: routine.id, name: routine.name, exerciseIDs: (routines[routine.id.rawValue] ?? []).map { ExerciseID($0) })
        }
        let others = routines.keys.filter { key in !Routine.defaults.contains { $0.id.rawValue == key } }.sorted().map { key in
            Routine(id: RoutineID(key), name: key, exerciseIDs: (routines[key] ?? []).map { ExerciseID($0) })
        }
        return defaults + others
    }

    private static func pendingSwaps(_ swaps: [String: PWAPendingSwap]) throws -> [RoutineID: PendingSwap] {
        var result: [RoutineID: PendingSwap] = [:]
        for (routine, swap) in swaps {
            result[RoutineID(routine)] = PendingSwap(from: ExerciseID(swap.fromExerciseId), to: ExerciseID(swap.toExerciseId), weekStart: try date(swap.weekStart))
        }
        return result
    }

    private static func session(_ session: PWASession) throws -> Session {
        Session(date: try date(session.date), routineID: RoutineID(session.type), completed: session.completed ?? true, logs: session.logs.map { log in
            ExerciseLog(exerciseID: ExerciseID(log.exercise_id), series: log.series, targetReps: log.reps.expected, actualReps: log.reps.actual ?? [],
                        weight: log.weight, skipped: log.skipped ?? false, swappedFrom: log.swappedFrom.map { ExerciseID($0) }, oneOff: log.oneOff ?? false)
        })
    }

    private static func date(_ iso: String) throws -> LocalDate {
        guard let date = LocalDate(iso: iso) else { throw PWAFormatError.invalidDate(iso) }
        return date
    }
}

// MARK: - Exportación

extension PWAFormat {
    /// Escribe el `db.json` que lee la PWA: los mismos campos y en el mismo orden que ella, con el
    /// nombre del ejercicio copiado en cada log, y los campos opcionales solo cuando hacen falta
    /// (`skipped` y `oneOff` solo si son `true`; `grupo` y `secundarios` solo si existen).
    /// Formato de `JSON.stringify(db, null, 2)`, para que los commits muestren solo lo que cambia.
    ///
    /// Lo que la PWA no puede guardar se pierde: el nombre de las rutinas que no son DIA1–DIA3
    /// (vuelven con el id por nombre).
    public static func json(from data: TrainingData) -> Data {
        Data(value(from: data).stringified().utf8)
    }

    static func value(from data: TrainingData) -> JSONValue {
        let exercises = data.catalog.all.map { exercise -> (key: String, value: JSONValue) in
            var fields: [(key: String, value: JSONValue)] = [("id", .string(exercise.id.rawValue)), ("name", .string(exercise.name))]
            if let group = exercise.group { fields.append(("grupo", .string(group.rawValue))) }
            if let secondaries = exercise.secondaryGroups { fields.append(("secundarios", .array(secondaries.map { .string($0.rawValue) }))) }
            return (exercise.id.rawValue, .object(fields))
        }
        let routines = data.routines.map { routine -> (key: String, value: JSONValue) in
            (routine.id.rawValue, .array(routine.exerciseIDs.map { .string($0.rawValue) }))
        }
        let history = data.history.map { session -> JSONValue in
            .object([
                ("date", .string(session.date.iso)),
                ("type", .string(session.routineID.rawValue)),
                ("logs", .array(session.logs.map { log(from: $0, catalog: data.catalog) })),
                ("completed", .bool(session.completed)),
            ])
        }
        let swaps = data.pendingSwaps.keys.sorted().map { routine -> (key: String, value: JSONValue) in
            let swap = data.pendingSwaps[routine]!
            return (routine.rawValue, .object([
                ("fromExerciseId", .string(swap.from.rawValue)),
                ("toExerciseId", .string(swap.to.rawValue)),
                ("weekStart", .string(swap.weekStart.iso)),
            ]))
        }
        return .object([
            ("exercises", .object(exercises)),
            ("routines", .object(routines)),
            ("history", .array(history)),
            ("pendingSwaps", .object(swaps)),
        ])
    }

    private static func log(from log: ExerciseLog, catalog: Catalog) -> JSONValue {
        var fields: [(key: String, value: JSONValue)] = [
            ("exercise_id", .string(log.exerciseID.rawValue)),
            ("name", .string(catalog.name(of: log.exerciseID))),
            ("series", .number(Double(log.series))),
            ("reps", .object([
                ("expected", .number(Double(log.targetReps))),
                ("actual", .array(log.actualReps.map { $0.map { .number(Double($0)) } ?? .null })),
            ])),
            ("weight", .number(log.weight)),
        ]
        if log.skipped { fields.append(("skipped", true)) }
        if let swappedFrom = log.swappedFrom { fields.append(("swappedFrom", .string(swappedFrom.rawValue))) }
        if log.oneOff { fields.append(("oneOff", true)) }
        return .object(fields)
    }
}

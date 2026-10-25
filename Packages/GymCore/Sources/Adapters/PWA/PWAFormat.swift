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
        let known = Set(exercises.keys)
        for log in history.flatMap(\.logs) where !known.contains(log.exercise_id) && !catalog.contains(where: { $0.id.rawValue == log.exercise_id }) {
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

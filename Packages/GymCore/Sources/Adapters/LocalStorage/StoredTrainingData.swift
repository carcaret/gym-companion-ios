import Domain

/// Formato del fichero local, versionado. Es propio de la app (no el `db.json` de la PWA):
/// copia el modelo tal cual, campo a campo, para que se pueda leer a ojo.
struct StoredTrainingData: Codable {
    static let currentVersion = 1

    var version: Int
    var exercises: [StoredExercise]
    var routines: [StoredRoutine]
    var pendingSwaps: [String: StoredPendingSwap]
    var history: [StoredSession]
}

struct StoredExercise: Codable {
    var id: String
    var name: String
    var group: String?
    var secondaryGroups: [String]?
}

struct StoredRoutine: Codable {
    var id: String
    var name: String
    var exerciseIDs: [String]
}

struct StoredPendingSwap: Codable {
    var from: String
    var to: String
    var weekStart: String
}

struct StoredSession: Codable {
    var date: String
    var routineID: String
    var completed: Bool
    var logs: [StoredLog]
}

struct StoredLog: Codable {
    var exerciseID: String
    var series: Int
    var targetReps: Int
    var actualReps: [Int?]
    var weight: Double
    var skipped: Bool
    var swappedFrom: String?
    var oneOff: Bool
}

/// Por qué no se puede leer el fichero local.
public enum StoredFormatError: Error, Hashable {
    case unsupportedVersion(Int)
    case invalidDate(String)
}

extension StoredTrainingData {
    init(_ data: TrainingData) {
        version = Self.currentVersion
        exercises = data.catalog.all.map {
            StoredExercise(id: $0.id.rawValue, name: $0.name, group: $0.group?.rawValue, secondaryGroups: $0.secondaryGroups?.map(\.rawValue))
        }
        routines = data.routines.map { StoredRoutine(id: $0.id.rawValue, name: $0.name, exerciseIDs: $0.exerciseIDs.map(\.rawValue)) }
        pendingSwaps = Dictionary(uniqueKeysWithValues: data.pendingSwaps.map { routine, swap in
            (routine.rawValue, StoredPendingSwap(from: swap.from.rawValue, to: swap.to.rawValue, weekStart: swap.weekStart.iso))
        })
        history = data.history.map { session in
            StoredSession(date: session.date.iso, routineID: session.routineID.rawValue, completed: session.completed, logs: session.logs.map {
                StoredLog(exerciseID: $0.exerciseID.rawValue, series: $0.series, targetReps: $0.targetReps, actualReps: $0.actualReps,
                          weight: $0.weight, skipped: $0.skipped, swappedFrom: $0.swappedFrom?.rawValue, oneOff: $0.oneOff)
            })
        }
    }

    func trainingData() throws(StoredFormatError) -> TrainingData {
        guard version == Self.currentVersion else { throw .unsupportedVersion(version) }
        var swaps: [RoutineID: PendingSwap] = [:]
        for (routine, swap) in pendingSwaps {
            swaps[RoutineID(routine)] = PendingSwap(from: ExerciseID(swap.from), to: ExerciseID(swap.to), weekStart: try Self.date(swap.weekStart))
        }
        var sessions: [Session] = []
        for session in history {
            sessions.append(Session(date: try Self.date(session.date), routineID: RoutineID(session.routineID), completed: session.completed, logs: session.logs.map {
                ExerciseLog(exerciseID: ExerciseID($0.exerciseID), series: $0.series, targetReps: $0.targetReps, actualReps: $0.actualReps,
                            weight: $0.weight, skipped: $0.skipped, swappedFrom: $0.swappedFrom.map { ExerciseID($0) }, oneOff: $0.oneOff)
            }))
        }
        return TrainingData(
            catalog: Catalog(exercises.map {
                Exercise(id: ExerciseID($0.id), name: $0.name, group: $0.group.map { MuscleGroup($0) }, secondaryGroups: $0.secondaryGroups?.map { MuscleGroup($0) })
            }),
            routines: routines.map { Routine(id: RoutineID($0.id), name: $0.name, exerciseIDs: $0.exerciseIDs.map { ExerciseID($0) }) },
            pendingSwaps: swaps,
            history: sessions
        )
    }

    private static func date(_ iso: String) throws(StoredFormatError) -> LocalDate {
        guard let date = LocalDate(iso: iso) else { throw .invalidDate(iso) }
        return date
    }
}

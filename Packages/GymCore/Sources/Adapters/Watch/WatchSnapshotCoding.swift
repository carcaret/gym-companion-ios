import Domain
import Foundation

/// Lo que viaja del iPhone al reloj, en JSON versionado: si un día cambia, un reloj con la app
/// vieja no lee mal lo que le llega de una nueva (ni al revés).
public enum WatchSnapshotCoding {
    /// 2: el plan de hoy y las sesiones de referencia en vez de las reps de hoy y las anteriores.
    /// Las rutinas para empezar en el reloj (`start`) van aparte y son opcionales, sin cambiar de
    /// versión: un reloj con la app de antes no las lee, y lo de un iPhone de antes llega sin ellas.
    static let currentVersion = 2

    /// Por qué no se puede leer lo recibido.
    public enum FormatError: Error, Hashable {
        case unsupportedVersion(Int)
        case invalidDate(String)
    }

    public static func encode(_ snapshot: WatchSnapshot) throws -> Data {
        try JSONEncoder().encode(Payload(snapshot))
    }

    public static func decode(_ data: Data) throws -> WatchSnapshot {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.version == currentVersion else { throw FormatError.unsupportedVersion(payload.version) }
        return try payload.snapshot()
    }
}

private struct Payload: Codable {
    struct Workout: Codable {
        var date: String
        var routineName: String
        var exercises: [Exercise]
    }

    struct Exercise: Codable {
        var name: String
        var weight: Double
        var series: Int
        var targetReps: Int
        var skipped: Bool
        var best: Reference?
        var last: Reference?
    }

    struct Reference: Codable {
        var date: String
        var weight: Double
        var reps: [Int?]
    }

    struct Start: Codable {
        var date: String
        var routines: [Routine]
        var completedRoutineName: String?
    }

    struct Routine: Codable {
        var id: String
        var plan: Workout
    }

    var version: Int
    var workout: Workout?
    var start: Start?

    init(_ snapshot: WatchSnapshot) {
        version = WatchSnapshotCoding.currentVersion
        workout = snapshot.workout.map(Workout.init)
        start = snapshot.start.map { start in
            Start(date: start.date.iso, routines: start.routines.map { Routine(id: $0.id.rawValue, plan: Workout($0.plan)) },
                  completedRoutineName: start.completedRoutineName)
        }
    }

    func snapshot() throws -> WatchSnapshot {
        try WatchSnapshot(
            workout: workout.map { try $0.workout() },
            start: start.map { start in
                try WatchSnapshot.Start(date: Self.date(start.date), routines: start.routines.map { routine in
                    try WatchSnapshot.Routine(id: RoutineID(routine.id), plan: routine.plan.workout())
                }, completedRoutineName: start.completedRoutineName)
            }
        )
    }

    fileprivate static func date(_ iso: String) throws -> LocalDate {
        guard let date = LocalDate(iso: iso) else { throw WatchSnapshotCoding.FormatError.invalidDate(iso) }
        return date
    }
}

private extension Payload.Workout {
    init(_ workout: WatchSnapshot.Workout) {
        self.init(date: workout.date.iso, routineName: workout.routineName, exercises: workout.exercises.map { exercise in
            Payload.Exercise(name: exercise.name, weight: exercise.weight, series: exercise.series, targetReps: exercise.targetReps,
                             skipped: exercise.skipped, best: exercise.best.map(Payload.Reference.init), last: exercise.last.map(Payload.Reference.init))
        })
    }

    func workout() throws -> WatchSnapshot.Workout {
        try WatchSnapshot.Workout(date: Payload.date(date), routineName: routineName, exercises: exercises.map { exercise in
            try WatchSnapshot.Exercise(name: exercise.name, weight: exercise.weight, series: exercise.series, targetReps: exercise.targetReps,
                                       skipped: exercise.skipped, best: exercise.best.map { try $0.reference() },
                                       last: exercise.last.map { try $0.reference() })
        })
    }
}

private extension Payload.Reference {
    init(_ reference: WatchSnapshot.Reference) {
        self.init(date: reference.date.iso, weight: reference.weight, reps: reference.reps)
    }

    func reference() throws -> WatchSnapshot.Reference {
        try WatchSnapshot.Reference(date: Payload.date(date), weight: weight, reps: reps)
    }
}

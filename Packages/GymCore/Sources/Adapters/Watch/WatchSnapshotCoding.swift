import Domain
import Foundation

/// Lo que viaja del iPhone al reloj, en JSON versionado: si un día cambia, un reloj con la app
/// vieja no lee mal lo que le llega de una nueva (ni al revés).
public enum WatchSnapshotCoding {
    static let currentVersion = 1

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
        var reps: [Int]
        var skipped: Bool
        var previous: [Previous]
    }

    struct Previous: Codable {
        var date: String
        var reps: [Int?]
    }

    var version: Int
    var workout: Workout?

    init(_ snapshot: WatchSnapshot) {
        version = WatchSnapshotCoding.currentVersion
        workout = snapshot.workout.map { workout in
            Workout(date: workout.date.iso, routineName: workout.routineName, exercises: workout.exercises.map { exercise in
                Exercise(name: exercise.name, weight: exercise.weight, reps: exercise.reps, skipped: exercise.skipped,
                         previous: exercise.previous.map { Previous(date: $0.date.iso, reps: $0.reps) })
            })
        }
    }

    func snapshot() throws -> WatchSnapshot {
        try WatchSnapshot(workout: workout.map { workout in
            try WatchSnapshot.Workout(date: Self.date(workout.date), routineName: workout.routineName, exercises: workout.exercises.map { exercise in
                try WatchSnapshot.Exercise(name: exercise.name, weight: exercise.weight, reps: exercise.reps, skipped: exercise.skipped,
                                           previous: exercise.previous.map { try WatchSnapshot.Previous(date: Self.date($0.date), reps: $0.reps) })
            })
        })
    }

    private static func date(_ iso: String) throws -> LocalDate {
        guard let date = LocalDate(iso: iso) else { throw WatchSnapshotCoding.FormatError.invalidDate(iso) }
        return date
    }
}

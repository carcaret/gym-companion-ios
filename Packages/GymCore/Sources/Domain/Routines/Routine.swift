/// Identificador estable de una rutina ("DIA1"). Es el `type` de cada sesión en `db.json`.
public struct RoutineID: Hashable, Comparable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var description: String { rawValue }

    /// Las tres rutinas de la PWA (`ROUTINE_KEYS`).
    public static let day1: RoutineID = "DIA1"
    public static let day2: RoutineID = "DIA2"
    public static let day3: RoutineID = "DIA3"

    public static func < (lhs: RoutineID, rhs: RoutineID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Una rutina: su nombre y los ejercicios en el orden en que se hacen.
public struct Routine: Hashable, Sendable {
    public let id: RoutineID
    public var name: String
    public var exerciseIDs: [ExerciseID]

    public init(id: RoutineID, name: String, exerciseIDs: [ExerciseID] = []) {
        self.id = id
        self.name = name
        self.exerciseIDs = exerciseIDs
    }

    /// Las tres rutinas de la PWA (`ROUTINE_KEYS` y `DAY_LABELS`), sin ejercicios: lo que hay
    /// cuando aún no se ha cargado nada. Sin referencias a días de la semana: se hacen cuando se
    /// puede, no un día fijo.
    public static let defaults: [Routine] = [
        Routine(id: .day1, name: "Full Body - Día 1"),
        Routine(id: .day2, name: "Full Body - Día 2"),
        Routine(id: .day3, name: "Full Body - Día 3"),
    ]
}

/// Un entreno de un día: qué rutina se hizo, si se terminó y lo hecho con cada ejercicio.
public struct Session: Hashable, Sendable {
    public var date: LocalDate
    public var routineID: RoutineID
    /// `false` mientras el entreno está en curso.
    public var completed: Bool
    public var logs: [ExerciseLog]

    public init(date: LocalDate, routineID: RoutineID, completed: Bool = false, logs: [ExerciseLog] = []) {
        self.date = date
        self.routineID = routineID
        self.completed = completed
        self.logs = logs
    }
}

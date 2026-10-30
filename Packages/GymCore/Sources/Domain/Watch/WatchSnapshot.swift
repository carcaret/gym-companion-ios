/// Lo que enseña el reloj: el entreno en curso, ejercicio a ejercicio, con el plan de hoy y las
/// sesiones de referencia (la mejor reciente y la última). El reloj solo lo lee; manda el iPhone.
public struct WatchSnapshot: Hashable, Sendable {
    public struct Workout: Hashable, Sendable {
        public let date: LocalDate
        public let routineName: String
        /// En el orden de la sesión.
        public let exercises: [Exercise]

        public init(date: LocalDate, routineName: String, exercises: [Exercise]) {
            self.date = date
            self.routineName = routineName
            self.exercises = exercises
        }
    }

    public struct Exercise: Hashable, Sendable {
        public let name: String
        /// El plan de hoy: el peso en kg (0 = peso corporal), las series y las reps objetivo.
        public let weight: Double
        public let series: Int
        public let targetReps: Int
        public let skipped: Bool
        /// La mejor sesión reciente (`History.bestRecentSession`): de ella sale el plan.
        public let best: Reference?
        /// La última vez que se hizo, solo si no es la mejor.
        public let last: Reference?

        public init(name: String, weight: Double, series: Int, targetReps: Int, skipped: Bool, best: Reference?, last: Reference?) {
            self.name = name
            self.weight = weight
            self.series = series
            self.targetReps = targetReps
            self.skipped = skipped
            self.best = best
            self.last = last
        }
    }

    /// Una sesión terminada del ejercicio: su día, el peso y las reps de cada serie (`nil` = sin
    /// rellenar).
    public struct Reference: Hashable, Sendable {
        public let date: LocalDate
        public let weight: Double
        public let reps: [Int?]

        public init(date: LocalDate, weight: Double, reps: [Int?]) {
            self.date = date
            self.weight = weight
            self.reps = reps
        }

        init(_ session: ExerciseSession) {
            self.init(date: session.date, weight: session.log.weight, reps: session.log.actualReps)
        }
    }

    /// `nil` = sin entreno en curso.
    public let workout: Workout?

    public init(workout: Workout?) {
        self.workout = workout
    }
}

extension TrainingData {
    /// Lo que enseña el reloj el día `today`: el entreno sin terminar de ese día, si lo hay.
    public func watchSnapshot(today: LocalDate) -> WatchSnapshot {
        guard let session = history.activeSession(on: today) else { return WatchSnapshot(workout: nil) }
        return WatchSnapshot(workout: WatchSnapshot.Workout(
            date: today,
            routineName: routines.name(of: session.routineID),
            exercises: session.logs.map { log in
                let best = history.bestRecentSession(for: log.exerciseID, today: today)
                let last = history.lastSessions(for: log.exerciseID, excluding: today, limit: 1).first
                return WatchSnapshot.Exercise(
                    name: catalog.name(of: log.exerciseID),
                    weight: log.weight,
                    series: log.series,
                    targetReps: log.targetReps,
                    skipped: log.skipped,
                    best: best.map(WatchSnapshot.Reference.init),
                    last: last.flatMap { $0.date == best?.date ? nil : WatchSnapshot.Reference($0) }
                )
            }
        ))
    }
}

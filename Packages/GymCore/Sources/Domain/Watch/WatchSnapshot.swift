/// Lo que enseña el reloj: el entreno en curso, ejercicio a ejercicio, con el peso y las reps de
/// hoy y las reps de las últimas sesiones terminadas. El reloj solo lo lee; manda el iPhone.
public struct WatchSnapshot: Hashable, Sendable {
    /// Sesiones anteriores que se enseñan de cada ejercicio.
    public static let previousLimit = 4

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
        /// En kg (0 = peso corporal).
        public let weight: Double
        /// Las reps de cada serie de hoy; una serie sin rellenar lleva las reps objetivo.
        public let reps: [Int]
        public let skipped: Bool
        /// De la más reciente a la más antigua, como mucho `previousLimit`.
        public let previous: [Previous]

        public init(name: String, weight: Double, reps: [Int], skipped: Bool, previous: [Previous]) {
            self.name = name
            self.weight = weight
            self.reps = reps
            self.skipped = skipped
            self.previous = previous
        }
    }

    /// Una sesión anterior terminada: su día y las reps de cada serie (`nil` = sin rellenar).
    public struct Previous: Hashable, Sendable {
        public let date: LocalDate
        public let reps: [Int?]

        public init(date: LocalDate, reps: [Int?]) {
            self.date = date
            self.reps = reps
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
        guard let session = history.session(on: today), !session.completed else { return WatchSnapshot(workout: nil) }
        let routineName = routines.first { $0.id == session.routineID }?.name ?? session.routineID.rawValue
        return WatchSnapshot(workout: WatchSnapshot.Workout(
            date: today,
            routineName: routineName,
            exercises: session.logs.map { log in
                WatchSnapshot.Exercise(
                    name: catalog.name(of: log.exerciseID),
                    weight: log.weight,
                    reps: (0..<log.series).map { index in
                        log.actualReps.indices.contains(index) ? log.actualReps[index] ?? log.targetReps : log.targetReps
                    },
                    skipped: log.skipped,
                    previous: history.lastSessions(for: log.exerciseID, excluding: today, limit: WatchSnapshot.previousLimit)
                        .map { WatchSnapshot.Previous(date: $0.date, reps: $0.log.actualReps) }
                )
            }
        ))
    }
}

/// Lo que enseña el reloj: el entreno en curso, ejercicio a ejercicio, con el plan de hoy y las
/// sesiones de referencia (la mejor reciente y la última); sin entreno, las rutinas para empezarlo
/// allí. El reloj solo lo lee; manda el iPhone.
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

    /// Sin entreno en curso, lo que hace falta para empezarlo en el reloj: cada rutina con el
    /// entreno que saldría al empezarla.
    public struct Start: Hashable, Sendable {
        /// El día para el que se ha calculado.
        public let date: LocalDate
        /// En el orden de las rutinas del iPhone.
        public let routines: [Routine]
        /// La rutina del entreno de ese día, si ya está terminado: empezar otra lo sustituye.
        public let completedRoutineName: String?

        public init(date: LocalDate, routines: [Routine], completedRoutineName: String?) {
            self.date = date
            self.routines = routines
            self.completedRoutineName = completedRoutineName
        }
    }

    /// Una rutina y el entreno que saldría al empezarla ese día (`startWorkout`).
    public struct Routine: Hashable, Sendable {
        public let id: RoutineID
        public let plan: Workout

        public init(id: RoutineID, plan: Workout) {
            self.id = id
            self.plan = plan
        }
    }

    /// `nil` = sin entreno en curso.
    public let workout: Workout?
    /// Sin entreno en curso, las rutinas para empezarlo; `nil` con entreno (o de un iPhone con la
    /// app de antes).
    public let start: Start?

    public init(workout: Workout?, start: Start? = nil) {
        self.workout = workout
        self.start = start
    }
}

extension WatchSnapshot.Exercise {
    /// La mejor, si es del peso de hoy: las reps de otro peso no dicen nada de la serie que toca
    /// (con el peso cambiado en el iPhone).
    public var bestAtTodayWeight: WatchSnapshot.Reference? {
        best?.weight == weight ? best : nil
    }

    /// La última, si es del peso de hoy.
    public var lastAtTodayWeight: WatchSnapshot.Reference? {
        last?.weight == weight ? last : nil
    }

    /// Nunca hecho: sin ninguna sesión, ni con otro peso.
    public var isFirstTime: Bool {
        best == nil && last == nil
    }
}

extension TrainingData {
    /// Lo que enseña el reloj el día `today`: el entreno sin terminar de ese día, si lo hay; si no,
    /// las rutinas para empezarlo allí.
    public func watchSnapshot(today: LocalDate) -> WatchSnapshot {
        guard let session = history.activeSession(on: today) else {
            return WatchSnapshot(workout: nil, start: watchStart(today: today))
        }
        return WatchSnapshot(workout: watchWorkout(session, today: today))
    }

    /// Cada rutina con el entreno que saldría al empezarla: el que hace `startWorkout`, con los
    /// cambios pendientes de la semana, para que el reloj enseñe lo mismo que el iPhone creará.
    private func watchStart(today: LocalDate) -> WatchSnapshot.Start {
        // Sin entreno en curso, el de hoy, si lo hay, está terminado.
        let done = history.session(on: today)
        let routines = routines.compactMap { routine -> WatchSnapshot.Routine? in
            var started = self
            started.startWorkout(routine: routine.id, on: today)
            guard let session = started.history.activeSession(on: today) else { return nil }
            return WatchSnapshot.Routine(id: routine.id, plan: started.watchWorkout(session, today: today))
        }
        return WatchSnapshot.Start(date: today, routines: routines, completedRoutineName: done.map { self.routines.name(of: $0.routineID) })
    }

    private func watchWorkout(_ session: Session, today: LocalDate) -> WatchSnapshot.Workout {
        WatchSnapshot.Workout(
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
        )
    }
}

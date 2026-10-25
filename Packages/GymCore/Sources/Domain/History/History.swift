/// Una sesión vista desde un ejercicio: su fecha y lo hecho con ese ejercicio.
public struct ExerciseSession: Hashable, Sendable {
    public let date: LocalDate
    public let log: ExerciseLog

    public init(date: LocalDate, log: ExerciseLog) {
        self.date = date
        self.log = log
    }
}

/// Una semana (de lunes a domingo) y la mejor sesión de un ejercicio en ella, si la hubo.
public struct WeekBucket: Hashable, Sendable {
    public let weekStart: LocalDate
    public let weekEnd: LocalDate
    public let session: ExerciseSession?
}

extension Collection where Element == Session {
    /// La sesión de ese día. (`getTodayEntry`.)
    public func session(on date: LocalDate) -> Session? {
        first { $0.date == date }
    }

    /// ¿Hay un entreno sin terminar ese día? (Mientras lo hay, la PWA no sincroniza.)
    public func isWorkoutActive(on date: LocalDate) -> Bool {
        session(on: date)?.completed == false
    }

    /// Lo hecho con un ejercicio en la sesión de ese día, por posición. (`findLog`.)
    public func log(on date: LocalDate, at index: Int) -> ExerciseLog? {
        guard let logs = session(on: date)?.logs, logs.indices.contains(index) else { return nil }
        return logs[index]
    }

    /// De la más antigua a la más reciente; las del mismo día conservan su orden.
    public func sortedChronologically() -> [Session] {
        enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }.map(\.element)
    }

    /// De la más reciente a la más antigua; las del mismo día conservan su orden.
    public func sortedNewestFirst() -> [Session] {
        enumerated().sorted { a, b in
            a.element.date != b.element.date ? a.element.date > b.element.date : a.offset < b.offset
        }.map(\.element)
    }

    /// ¿Se terminó una sesión de esa rutina en la semana que empieza en `weekStart`?
    public func hasCompletedSession(of routine: RoutineID, inWeekStarting weekStart: LocalDate) -> Bool {
        let weekEnd = weekStart.adding(days: 6)
        return contains { $0.completed && $0.routineID == routine && (weekStart...weekEnd).contains($0.date) }
    }

    /// Sesiones terminadas del ejercicio en las últimas `weeks` semanas hasta `anchor` (la semana
    /// de `anchor` cuenta entera desde su lunes), de la más antigua a la más reciente, como mucho
    /// las `maxSessions` últimas. Son las barras de la gráfica de cada ejercicio en Hoy.
    public func recentSessions(
        for exercise: ExerciseID, anchor: LocalDate, maxSessions: Int = 6, weeks: Int = 6, excluding excluded: LocalDate? = nil
    ) -> [ExerciseSession] {
        let windowStart = anchor.weekStart.adding(days: -7 * (weeks - 1))
        let sessions = sortedChronologically().compactMap { session -> ExerciseSession? in
            guard session.completed, session.date != excluded, (windowStart...anchor).contains(session.date),
                  let log = session.logs.first(where: { $0.exerciseID == exercise }) else { return nil }
            return ExerciseSession(date: session.date, log: log)
        }
        return Array(sessions.suffix(maxSessions))
    }

    /// Las `limit` últimas sesiones terminadas en las que se hizo el ejercicio (sin saltarlo), de
    /// la más reciente a la más antigua, sin límite de fechas. Son las del reloj.
    public func lastSessions(for exercise: ExerciseID, excluding excluded: LocalDate? = nil, limit: Int) -> [ExerciseSession] {
        let sessions = sortedNewestFirst().lazy.compactMap { session -> ExerciseSession? in
            guard session.completed, session.date != excluded,
                  let log = session.logs.first(where: { $0.exerciseID == exercise }), !log.skipped else { return nil }
            return ExerciseSession(date: session.date, log: log)
        }
        return Array(sessions.prefix(limit))
    }

    /// Las últimas `weeks` semanas hasta la de `anchor`, de la más antigua a la actual, cada una
    /// con su sesión terminada de mayor volumen del ejercicio (a igualdad, la más reciente).
    public func weeklyBuckets(
        for exercise: ExerciseID, anchor: LocalDate, weeks: Int = 4, excluding excluded: LocalDate? = nil
    ) -> [WeekBucket] {
        let anchorWeek = anchor.weekStart
        return (0..<weeks).reversed().map { weeksAgo in
            let weekStart = anchorWeek.adding(days: -7 * weeksAgo)
            let weekEnd = weekStart.adding(days: 6)
            var best: ExerciseSession?
            for session in self where session.completed && session.date != excluded && (weekStart...weekEnd).contains(session.date) {
                guard let log = session.logs.first(where: { $0.exerciseID == exercise }) else { continue }
                if let current = best, log.volume < current.log.volume || (log.volume == current.log.volume && session.date <= current.date) {
                    continue
                }
                best = ExerciseSession(date: session.date, log: log)
            }
            return WeekBucket(weekStart: weekStart, weekEnd: weekEnd, session: best)
        }
    }

    /// Con qué valores arranca un ejercicio al planificar la sesión de `today`.
    ///
    /// 1. La mejor sesión terminada (no saltada) de la misma ventana que pinta la gráfica (las
    ///    últimas `weeks` semanas): más peso; a igualdad, más volumen; a igualdad, la más reciente.
    /// 2. Si no hay ninguna (ejercicio "dormido"), la vez más reciente que se hizo, terminada o no:
    ///    la más reciente y no la de más peso, para no resucitar pesos antiguos.
    /// 3. Si nunca se hizo, `LogSeed.defaults`.
    ///
    /// La sesión de `today` nunca cuenta (es la que se está planificando).
    public func bestRecentSeed(for exercise: ExerciseID, today: LocalDate? = nil, weeks: Int = 6) -> LogSeed {
        if let today {
            let sessions = recentSessions(for: exercise, anchor: today, maxSessions: 6, weeks: weeks, excluding: today)
                .filter { !$0.log.skipped }
            if var best = sessions.last?.log {
                for log in sessions.dropLast().reversed().map(\.log)
                where log.weight > best.weight || (log.weight == best.weight && log.volume > best.volume) {
                    best = log
                }
                return LogSeed(best)
            }
        }
        for session in sortedChronologically().reversed() where session.date != today {
            if let log = session.logs.first(where: { $0.exerciseID == exercise && !$0.skipped }) {
                return LogSeed(log)
            }
        }
        return .defaults
    }
}

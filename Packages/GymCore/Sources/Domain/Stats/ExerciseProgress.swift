/// Cómo va un ejercicio. (`'progresa'`, `'estancado'`, `'sin-recorrido'` en la PWA.)
public enum ProgressStatus: Hashable, Sendable {
    case progressing
    case stalled
    /// Menos de 3 sesiones con reps: aún no se puede decir.
    case noTrack
}

/// Estado de progreso de un ejercicio en una ventana de semanas (tarjeta Ejercicios de
/// Estadísticas). Diseño: `docs/superpowers/specs/2026-08-25-estadisticas-design.md` de la PWA.
public struct ExerciseProgress: Hashable, Sendable {
    public var exerciseID: ExerciseID
    public var name: String
    /// Peso de la última sesión.
    public var weight: Double
    /// Reps de las 3 últimas sesiones, la más antigua primero.
    public var recentReps: [[Int]]
    public var status: ProgressStatus
    /// Sesiones al peso actual desde el último récord de reps (0 si progresa).
    public var stallSessions: Int
    public var weightFrom: Double?
    public var weightTo: Double?
    /// Reps totales de la primera y la última sesión al peso actual dentro de la ventana.
    public var repsFrom: Int?
    public var repsTo: Int?
    /// Récord de reps totales al peso actual.
    public var bestReps: Int
    /// Fecha del último récord, si está estancado.
    public var stallSince: LocalDate?
    /// Sesiones con reps hechas.
    public var sessionCount: Int
    /// Días que describe la frase (desde el último récord, o desde la última sesión con el peso
    /// anterior); `nil` si no hay recorrido.
    public var spanDays: Int?
    /// ¿Se cumplió el objetivo en todas las series de la racha? Solo elige la redacción.
    public var allHit: Bool?

    public init(
        exerciseID: ExerciseID = "", name: String = "", weight: Double = 0, recentReps: [[Int]] = [],
        status: ProgressStatus = .noTrack, stallSessions: Int = 0, weightFrom: Double? = nil, weightTo: Double? = nil,
        repsFrom: Int? = nil, repsTo: Int? = nil, bestReps: Int = 0, stallSince: LocalDate? = nil,
        sessionCount: Int = 0, spanDays: Int? = nil, allHit: Bool? = nil
    ) {
        self.exerciseID = exerciseID
        self.name = name
        self.weight = weight
        self.recentReps = recentReps
        self.status = status
        self.stallSessions = stallSessions
        self.weightFrom = weightFrom
        self.weightTo = weightTo
        self.repsFrom = repsFrom
        self.repsTo = repsTo
        self.bestReps = bestReps
        self.stallSince = stallSince
        self.sessionCount = sessionCount
        self.spanDays = spanDays
        self.allHit = allHit
    }
}

extension Collection where Element == Session {
    /// Sesiones no saltadas del ejercicio entre `from` y `to` (incluidos; sin `from`, desde el
    /// principio), de la más antigua a la más reciente.
    public func sessions(of exercise: ExerciseID, from: LocalDate? = nil, to: LocalDate) -> [ExerciseSession] {
        sortedChronologically()
            .filter { session in session.date >= (from ?? session.date) && session.date <= to }
            .flatMap { session in
                session.logs.filter { $0.exerciseID == exercise && !$0.skipped }.map { ExerciseSession(date: session.date, log: $0) }
            }
    }
}

extension TrainingData {
    private static let recentSessionsShown = 3
    private static let minimumSessions = 3

    /// Progreso de un ejercicio en las `weeks` semanas anteriores a `anchor`.
    ///
    /// Progresa si sube el peso o si la última sesión batió el récord de reps totales al peso
    /// actual. Nunca se compara con el objetivo de reps: lo teclea el usuario y lo sube según
    /// progresa, así que medir contra él marcaría como estancado a quien mejora. Tampoco vale
    /// comparar primera y última de la ventana: con 30-32-32-31 la última supera a la primera,
    /// pero el récord de 32 lleva sin batirse desde la segunda.
    public func progress(of exercise: ExerciseID, anchor: LocalDate, weeks: Int = 8) -> ExerciseProgress {
        let from = anchor.adding(days: -weeks * 7)
        let withReps = history.sessions(of: exercise, to: anchor).filter { $0.log.totalReps > 0 }
        var progress = ExerciseProgress(exerciseID: exercise, name: catalog.name(of: exercise), sessionCount: withReps.count)
        guard let last = withReps.last else { return progress }

        let weight = last.log.weight
        progress.weight = weight
        progress.recentReps = withReps.suffix(Self.recentSessionsShown).map { $0.log.actualReps.compactMap { $0 } }
        guard withReps.count >= Self.minimumSessions else { return progress }

        let inWindow = withReps.filter { $0.date >= from }
        let scope = inWindow.isEmpty ? [last] : inWindow
        let weightFrom = scope[0].log.weight
        let weightWentUp = weight > weightFrom
        let atWeightInScope = scope.filter { $0.log.weight == weight }

        // Racha: sesiones al peso actual desde la última que batió el récord de reps, esa
        // incluida. Empatar no es batir: 9-9-9 seis veces seguidas son seis de racha.
        let atWeight = withReps.filter { $0.log.weight == weight }
        var record = -1
        var lastImprovement = 0
        for (index, session) in atWeight.enumerated() where session.log.totalReps > record {
            record = session.log.totalReps
            lastImprovement = index
        }
        let streak = atWeight.count - lastImprovement
        let progressing = weightWentUp || streak == 1

        // Lo que describe la frase. Estancado: desde el último récord. Subida de peso: desde la
        // última sesión con la carga vieja (desde el principio de la ventana contaría semanas en
        // las que no pasó nada).
        var spanFrom = anchor
        if !progressing {
            spanFrom = atWeight[lastImprovement].date
        } else if weightWentUp, let lastOld = scope.last(where: { $0.log.weight == weightFrom }) {
            spanFrom = lastOld.date
        }

        progress.status = progressing ? .progressing : .stalled
        progress.stallSessions = progressing ? 0 : streak
        progress.stallSince = progressing ? nil : atWeight[lastImprovement].date
        progress.bestReps = record
        progress.weightFrom = weightFrom
        progress.weightTo = weight
        progress.repsFrom = atWeightInScope.first?.log.totalReps
        progress.repsTo = atWeightInScope.last?.log.totalReps
        progress.spanDays = spanFrom.days(until: anchor)
        progress.allHit = atWeight[lastImprovement...].allSatisfy { session in
            session.log.actualReps.allSatisfy { ($0 ?? .max) >= session.log.targetReps }
        }
        return progress
    }

    /// Filas de la tarjeta Ejercicios: primero los que llevan más sesiones sin moverse, después
    /// los que progresan y al final los que aún no tienen recorrido; a igualdad, por nombre.
    public func progressRows(for exercises: [ExerciseID], anchor: LocalDate, weeks: Int = 8) -> [ExerciseProgress] {
        func rank(_ status: ProgressStatus) -> Int {
            switch status {
            case .stalled: 0
            case .progressing: 1
            case .noTrack: 2
            }
        }
        return exercises.map { progress(of: $0, anchor: anchor, weeks: weeks) }.sorted { a, b in
            if rank(a.status) != rank(b.status) { return rank(a.status) < rank(b.status) }
            if a.stallSessions != b.stallSessions { return a.stallSessions > b.stallSessions }
            return SpanishCollation.precedes(a.name, b.name)
        }
    }
}

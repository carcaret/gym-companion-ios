/// Cómo va un ejercicio. (`'progresa'`, `'estancado'`, `'sin-recorrido'` en la PWA.)
public enum ProgressStatus: Hashable, Sendable {
    case progressing
    case stalled
    /// Menos de 3 sesiones con reps: aún no se puede decir.
    case noTrack
}

/// Estado de progreso de un ejercicio en una ventana de semanas (la sección Ejercicios
/// de Progreso). Diseño: `docs/superpowers/specs/2026-08-25-estadisticas-design.md` de la PWA.
public struct ExerciseProgress: Hashable, Sendable {
    public var exerciseID: ExerciseID
    public var name: String
    /// Peso de la última sesión.
    public var weight: Double
    /// Las 3 últimas sesiones, la más antigua primero.
    public var recentSessions: [RecentSession]
    /// Sus reps.
    public var recentReps: [[Int]] { recentSessions.map(\.reps) }
    public var status: ProgressStatus
    /// Sesiones al peso actual después del último récord de reps, las que no lo han superado (0 si
    /// la última lo batió). También en los que progresan sin llegar al umbral del estancado.
    public var sessionsWithoutRecord: Int
    /// Sesiones al peso actual desde el último récord de reps, esa incluida, si está estancado (0 si no).
    public var stallSessions: Int { status == .stalled ? sessionsWithoutRecord + 1 : 0 }
    public var weightFrom: Double?
    public var weightTo: Double?
    /// Lo avanzado en la ventana: reps totales de la primera sesión al peso actual dentro de ella y
    /// las del récord. Iguales si el récord es la primera, o es de antes de la ventana.
    public var repsFrom: Int?
    public var repsTo: Int?
    /// Récord de reps totales al peso actual.
    public var bestReps: Int
    /// Fecha del último récord, si está estancado.
    public var stallSince: LocalDate?
    /// Sesiones con reps hechas.
    public var sessionCount: Int
    /// Días desde la última sesión con el peso anterior, en una subida de peso (los que dice su
    /// frase); `nil` en lo demás.
    public var spanDays: Int?
    /// ¿Se cumplió el objetivo en todas las series de la racha? Solo elige la redacción.
    public var allHit: Bool?
    /// En los estancados, cómo cambiaron la 1.ª y la última serie desde la sesión del récord; `nil`
    /// si no cambió ninguna.
    public var setsChange: SetsChange?
    /// La última sesión con reps de hace `ProgressWindow.lookBackMonths` meses o antes, si no es de
    /// hace más de `ProgressWindow.lookBackLimitMonths`.
    public var lookBack: ExerciseSession?

    public init(
        exerciseID: ExerciseID = "", name: String = "", weight: Double = 0, recentSessions: [RecentSession] = [],
        status: ProgressStatus = .noTrack, sessionsWithoutRecord: Int = 0, weightFrom: Double? = nil, weightTo: Double? = nil,
        repsFrom: Int? = nil, repsTo: Int? = nil, bestReps: Int = 0, stallSince: LocalDate? = nil,
        sessionCount: Int = 0, spanDays: Int? = nil, allHit: Bool? = nil, setsChange: SetsChange? = nil,
        lookBack: ExerciseSession? = nil
    ) {
        self.exerciseID = exerciseID
        self.name = name
        self.weight = weight
        self.recentSessions = recentSessions
        self.status = status
        self.sessionsWithoutRecord = sessionsWithoutRecord
        self.weightFrom = weightFrom
        self.weightTo = weightTo
        self.repsFrom = repsFrom
        self.repsTo = repsTo
        self.bestReps = bestReps
        self.stallSince = stallSince
        self.sessionCount = sessionCount
        self.spanDays = spanDays
        self.allHit = allHit
        self.setsChange = setsChange
        self.lookBack = lookBack
    }
}

/// Las reps de la 1.ª y la última serie en la sesión del récord y en la última: «1.ª serie 11 → 12 ·
/// última 8 → 6». Describe en qué serie se ganó o se perdió; no es la caída dentro de una sesión,
/// que es el patrón normal y el diseño de Estadísticas de la PWA descartó como señal.
public struct SetsChange: Hashable, Sendable {
    public let firstFrom: Int
    public let firstTo: Int
    public let lastFrom: Int
    public let lastTo: Int

    public init(firstFrom: Int, firstTo: Int, lastFrom: Int, lastTo: Int) {
        self.firstFrom = firstFrom
        self.firstTo = firstTo
        self.lastFrom = lastFrom
        self.lastTo = lastTo
    }

    /// `nil` si no cambió ni la 1.ª ni la última, o si alguna de las dos sesiones tiene una sola
    /// serie (entonces la frase del estancado ya lo dice).
    public init?(record: ExerciseLog, last: ExerciseLog) {
        let before = record.actualReps.compactMap { $0 }
        let after = last.actualReps.compactMap { $0 }
        guard before.count > 1, after.count > 1, let firstFrom = before.first, let lastFrom = before.last,
              let firstTo = after.first, let lastTo = after.last, firstFrom != firstTo || lastFrom != lastTo else { return nil }
        self.init(firstFrom: firstFrom, firstTo: firstTo, lastFrom: lastFrom, lastTo: lastTo)
    }
}

/// Una de las últimas sesiones de un ejercicio: su día y las reps de cada serie.
public struct RecentSession: Hashable, Sendable {
    public let date: LocalDate
    public let reps: [Int]

    public init(date: LocalDate, reps: [Int]) {
        self.date = date
        self.reps = reps
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
    /// Estancado si lleva al menos 3 sesiones y 28 días sin superar el récord de reps totales al peso
    /// actual (`StallThreshold`, decisión del usuario, 2026-11-27); si no, progresa, con lo avanzado
    /// en la ventana hasta el récord. La primera sesión a un peso nuevo lo bate siempre, así que
    /// subir de peso es progreso hasta que a ese peso deja de mejorar. Lo que pasó antes no cuenta:
    /// con 12 → 14 kg y después cuatro sesiones iguales a 14 durante un mes, está estancado
    /// (decisión del usuario, 2026-11-02; la PWA lo daba por progreso mientras la subida cayera en
    /// la ventana). Nunca se compara con el objetivo de reps: lo teclea el usuario y lo sube según
    /// progresa, así que medir contra él marcaría como estancado a quien mejora. Tampoco vale
    /// comparar primera y última de la ventana: con 30-32-32-31 la última supera a la primera, pero
    /// el récord de 32 lleva sin batirse desde la segunda.
    public func progress(of exercise: ExerciseID, anchor: LocalDate, weeks: Int = ProgressWindow.weeks) -> ExerciseProgress {
        let from = anchor.adding(days: -weeks * 7)
        let withReps = history.sessions(of: exercise, to: anchor).filter { $0.log.totalReps > 0 }
        var progress = ExerciseProgress(exerciseID: exercise, name: catalog.name(of: exercise), sessionCount: withReps.count)
        guard let last = withReps.last else { return progress }

        let weight = last.log.weight
        progress.weight = weight
        progress.recentSessions = withReps.suffix(Self.recentSessionsShown).map { RecentSession(date: $0.date, reps: $0.log.actualReps.compactMap { $0 }) }
        let lookBackDate = anchor.adding(months: -ProgressWindow.lookBackMonths)
        let lookBackLimit = anchor.adding(months: -ProgressWindow.lookBackLimitMonths)
        progress.lookBack = withReps.last { $0.date <= lookBackDate }.flatMap { $0.date >= lookBackLimit ? $0 : nil }
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
        let recordSession = atWeight[lastImprovement]
        let sessionsWithoutRecord = atWeight.count - lastImprovement - 1
        let stalled = sessionsWithoutRecord >= StallThreshold.minimumSessionsWithoutRecord
            && recordSession.date.days(until: anchor) >= StallThreshold.minimumDaysWithoutRecord

        // Lo que describe la frase de una subida de peso: desde la última sesión con la carga vieja
        // (desde el principio de la ventana contaría semanas en las que no pasó nada).
        if !stalled, weightWentUp, let lastOld = scope.last(where: { $0.log.weight == weightFrom }) {
            progress.spanDays = lastOld.date.days(until: anchor)
        }

        progress.status = stalled ? .stalled : .progressing
        progress.sessionsWithoutRecord = sessionsWithoutRecord
        progress.stallSince = stalled ? recordSession.date : nil
        progress.setsChange = stalled ? SetsChange(record: recordSession.log, last: last.log) : nil
        progress.bestReps = record
        progress.weightFrom = weightFrom
        progress.weightTo = weight
        progress.repsFrom = atWeightInScope.first { $0.date <= recordSession.date }?.log.totalReps ?? record
        progress.repsTo = record
        progress.allHit = atWeight[lastImprovement...].allSatisfy { session in
            session.log.actualReps.allSatisfy { $0.map { RepOutcome(reps: $0, target: session.log.targetReps).meetsTarget } ?? true }
        }
        return progress
    }

    /// Filas de la tarjeta Ejercicios: primero los que llevan más sesiones sin moverse, después
    /// los que progresan y al final los que aún no tienen recorrido; a igualdad, por nombre.
    public func progressRows(for exercises: [ExerciseID], anchor: LocalDate, weeks: Int = ProgressWindow.weeks) -> [ExerciseProgress] {
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

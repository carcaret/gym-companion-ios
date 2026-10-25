/// Valores con los que arranca un ejercicio al planificar una sesión: normalmente los de la mejor
/// sesión reciente (`bestRecentSeed`), o los de por defecto si nunca se ha hecho.
public struct LogSeed: Hashable, Sendable {
    public var series: Int
    public var targetReps: Int
    public var weight: Double
    public var actualReps: [Int?]

    public init(series: Int, targetReps: Int, weight: Double, actualReps: [Int?] = []) {
        self.series = series
        self.targetReps = targetReps
        self.weight = weight
        self.actualReps = actualReps
    }

    /// 3 series de 10 sin peso.
    public static let defaults = LogSeed(series: 3, targetReps: 10, weight: 0)

    init(_ log: ExerciseLog) {
        self.init(series: log.series, targetReps: log.targetReps, weight: log.weight, actualReps: log.actualReps)
    }
}

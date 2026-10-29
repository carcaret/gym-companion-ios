import Application
import Domain

/// Doble de la sesión de entreno del reloj: el tiempo lo pone el test (`elapsedTime`), lo medido
/// llega con `emit`, y apunta cuántas veces se empieza y se termina.
@MainActor
public final class FakeWorkoutRecorder: WorkoutRecorder {
    public struct Failure: Error {}

    public var onMetrics: (@MainActor (WorkoutMetrics) -> Void)?
    /// El tiempo de entreno que devuelve `elapsed()` mientras mide.
    public var elapsedTime: Duration = .zero
    /// Lo que devuelve `end()`.
    public var summary = WorkoutSummary(duration: .seconds(3000), activeEnergy: 412, totalEnergy: 520, averageHeartRate: 118)
    /// Lo medido que llega mientras arranca, como puede pasar con Salud.
    public var metricsOnStart: WorkoutMetrics?
    public var failsToStart = false
    public var failsToEnd = false
    public private(set) var starts = 0
    public private(set) var ends = 0
    public private(set) var isRecording = false

    public init() {}

    public func start() async throws {
        starts += 1
        if failsToStart { throw Failure() }
        isRecording = true
        if let metricsOnStart { onMetrics?(metricsOnStart) }
    }

    public func elapsed() -> Duration {
        isRecording ? elapsedTime : .zero
    }

    public func end() async throws -> WorkoutSummary {
        ends += 1
        isRecording = false
        if failsToEnd { throw Failure() }
        return summary
    }

    /// Una medida nueva de Salud.
    public func emit(_ metrics: WorkoutMetrics) {
        onMetrics?(metrics)
    }
}

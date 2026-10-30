import Application
import Domain

/// Lo que enseña el reloj en las capturas del CI: el Día 1 de `DemoData` en curso, como si se
/// acabara de empezar en el iPhone, o nada con `-demo-sin-entreno`. Nunca se usa en el reloj.
enum WatchDemo {
    static func snapshot(arguments: [String], today: LocalDate) -> WatchSnapshot? {
        if LaunchArgument.demoWithoutWorkout.isPresent(in: arguments) { return WatchSnapshot(workout: nil) }
        guard LaunchArgument.demo.isPresent(in: arguments) else { return nil }
        var data = DemoData.make(today: today)
        data.startWorkout(routine: data.routines[0].id, on: today)
        return data.watchSnapshot(today: today)
    }
}

/// La sesión de entreno de las capturas: empieza en 23:41, con el pulso y las kcal fijos, sin
/// tocar Salud.
@MainActor
final class DemoWorkoutRecorder: WorkoutRecorder {
    var onMetrics: (@MainActor (WorkoutMetrics) -> Void)?
    private var startedAt: ContinuousClock.Instant?

    func start(on day: LocalDate) async throws {
        startedAt = .now
        onMetrics?(WorkoutMetrics(heartRate: 128, activeEnergy: 172, totalEnergy: 221))
    }

    func elapsed() -> Duration {
        guard let startedAt else { return .zero }
        return .seconds(1421) + startedAt.duration(to: .now)
    }

    func end() async throws -> WorkoutSummary {
        let duration = elapsed()
        startedAt = nil
        return WorkoutSummary(duration: duration, activeEnergy: 412, totalEnergy: 520, averageHeartRate: 118)
    }
}

/// Sin vibración en las capturas.
@MainActor
final class DemoRestAlert: RestAlert {
    func schedule(after delay: Duration) {}
    func cancel() {}
}

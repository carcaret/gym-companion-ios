import Application
import Domain

/// Lo que enseña el reloj en las capturas del CI: el Día 1 de `DemoData` en curso, como si se
/// acabara de empezar en el iPhone, o nada con `-demo-sin-entreno`. Nunca se usa en el reloj.
enum WatchDemo {
    static func snapshot(arguments: [String], today: LocalDate) -> WatchSnapshot? {
        if LaunchArgument.demoWithoutWorkout.isPresent(in: arguments) { return WatchSnapshot(workout: nil) }
        guard LaunchArgument.demo.isPresent(in: arguments) else { return nil }
        // PRUEBA: el Día 3 real del usuario (2026-10-31).
        func ref(_ d: String, _ w: Double, _ r: [Int?]) -> WatchSnapshot.Reference { .init(date: LocalDate(iso: d)!, weight: w, reps: r) }
        return WatchSnapshot(workout: .init(date: today, routineName: "Día 3", exercises: [
            .init(name: "Press Inclinado en Máquina", weight: 32.5, series: 4, targetReps: 11, skipped: false,
                  best: ref("2026-09-25", 32.5, [11, 11, 11, 11]), last: ref("2026-10-24", 32.5, [12, 11, 10, 8])),
            .init(name: "Jalón al pecho neutro", weight: 73, series: 4, targetReps: 10, skipped: false,
                  best: ref("2026-10-02", 73, [10, 10, 10, 8]), last: ref("2026-10-24", 73, [10, 10, 9, 8])),
        ]))
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

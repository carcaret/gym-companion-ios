import Domain
import GymCoreTesting
import ViewModels

/// La pantalla del reloj con los dobles de la sesión de Salud y de la vibración.
@MainActor
struct WatchHarness {
    let model: WatchModel
    let recorder = FakeWorkoutRecorder()
    let alert = RecordingRestAlert()

    init(today: LocalDate) {
        model = WatchModel(clock: FixedClock(today), recorder: recorder, restAlert: alert)
    }

    /// Con el entreno recibido y empezado a medir.
    static func recording(_ snapshot: WatchSnapshot, today: LocalDate) async -> WatchHarness {
        let watch = WatchHarness(today: today)
        await watch.model.receive(snapshot)
        await watch.model.start()
        return watch
    }
}

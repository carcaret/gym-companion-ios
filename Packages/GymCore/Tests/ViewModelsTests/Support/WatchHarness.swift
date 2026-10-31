import Domain
import GymCoreTesting
import ViewModels

/// La pantalla del reloj con los dobles de la sesión de Salud, de la vibración y del iPhone.
@MainActor
struct WatchHarness {
    let model: WatchModel
    let recorder = FakeWorkoutRecorder()
    let alert = RecordingRestAlert()
    let phone = RecordingPhoneWorkoutFinisher()

    init(today: LocalDate) {
        model = WatchModel(clock: FixedClock(today), recorder: recorder, restAlert: alert, phone: phone)
    }

    /// Con el entreno recibido y empezado a medir.
    static func recording(_ snapshot: WatchSnapshot, today: LocalDate) async -> WatchHarness {
        let watch = WatchHarness(today: today)
        await watch.model.receive(snapshot)
        await watch.model.start()
        return watch
    }
}

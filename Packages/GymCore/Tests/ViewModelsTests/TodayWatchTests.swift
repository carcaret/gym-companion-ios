import GymCoreTesting
import Testing
import ViewModels

// La app del reloj mide el entreno (#17): empezar en el iPhone abre el reloj.

@MainActor
@Suite("Empezar abre el reloj")
struct TodayWatchTests {
    @Test("empezar el entreno abre la app del reloj")
    func launches() async {
        let launcher = RecordingWatchWorkoutLauncher()
        let today = await TodayHarness.make(watchLauncher: launcher)
        await today.start()
        #expect(launcher.launches == 1)
        #expect(today.model.stage == .active)
    }

    @Test("sin empezar (solo viendo la rutina), no lo abre")
    func previewDoesNotLaunch() async {
        let launcher = RecordingWatchWorkoutLauncher()
        let today = await TodayHarness.make(watchLauncher: launcher)
        today.model.select("DIA1")
        #expect(launcher.launches == 0)
    }
}

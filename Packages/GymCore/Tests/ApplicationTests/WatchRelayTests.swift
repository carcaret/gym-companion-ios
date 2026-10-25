import Application
import Domain
import GymCoreTesting
import Testing

@MainActor
@Suite("Envío al reloj")
struct WatchRelayTests {
    private let today = SyncFixtures.today

    @Test("envía lo que enseña el reloj con los datos de hoy")
    func sends() {
        let publisher = RecordingWatchPublisher()
        let relay = WatchRelay(publisher: publisher, clock: FixedClock(today))
        relay.send(SyncFixtures.activeWorkout())
        #expect(publisher.published == [SyncFixtures.activeWorkout().watchSnapshot(today: today)])
    }

    @Test("lo mismo no se vuelve a enviar")
    func deduplicates() {
        let publisher = RecordingWatchPublisher()
        let relay = WatchRelay(publisher: publisher, clock: FixedClock(today))
        relay.send(SyncFixtures.activeWorkout())
        relay.send(SyncFixtures.activeWorkout())
        // Un cambio que el reloj no enseña (otro ejercicio en el catálogo) tampoco.
        relay.send(SyncFixtures.adding(Exercise(id: "remo", name: "Remo"), to: SyncFixtures.activeWorkout()))
        #expect(publisher.published.count == 1)
    }

    @Test("un cambio que el reloj enseña se envía")
    func sendsChanges() {
        let publisher = RecordingWatchPublisher()
        let relay = WatchRelay(publisher: publisher, clock: FixedClock(today))
        relay.send(SyncFixtures.activeWorkout())
        relay.send(SyncFixtures.activeWorkout(weight: 62.5))
        relay.send(SyncFixtures.finishedWorkout())
        #expect(publisher.published.map { $0.workout?.exercises.first?.weight } == [60, 62.5, nil])
    }

    @Test("sin datos cargados no envía nada")
    func withoutData() {
        let publisher = RecordingWatchPublisher()
        WatchRelay(publisher: publisher, clock: FixedClock(today)).send(nil)
        #expect(publisher.published.isEmpty)
    }

    @Test("al cambiar de día, el entreno de ayer sin terminar deja de enviarse")
    func dayChange() {
        let publisher = RecordingWatchPublisher()
        let clock = SettableClock(today)
        let relay = WatchRelay(publisher: publisher, clock: clock)
        relay.send(SyncFixtures.activeWorkout())
        clock.day = today.adding(days: 1)
        relay.send(SyncFixtures.activeWorkout())
        #expect(publisher.published.map { $0.workout == nil } == [false, true])
    }
}

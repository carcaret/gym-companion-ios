import Domain
import Testing

// El descanso del reloj (decisión del usuario, 2026-10-29): un toque lo empieza desde cero, otro
// lo para y lo deja a cero; a 1:30 vibra y sigue; a 2:30 vuelve solo a cero.

@Suite("Descanso del reloj")
struct RestTimerTests {
    @Test("sin tocar, a cero")
    func idle() {
        #expect(RestTimer().state(at: .seconds(600)) == .idle)
    }

    @Test("un toque lo empieza y cuenta desde cero")
    func starts() {
        var timer = RestTimer()
        timer.tap(at: .seconds(600))
        #expect(timer.state(at: .seconds(600)) == .resting(.zero))
        #expect(timer.state(at: .seconds(645)) == .resting(.seconds(45)))
    }

    @Test("a 1:30 está cumplido y sigue contando")
    func overdue() {
        var timer = RestTimer()
        timer.tap(at: .seconds(600))
        #expect(timer.state(at: .seconds(689)) == .resting(.seconds(89)))
        #expect(timer.state(at: .seconds(690)) == .overdue(.seconds(90)))
        #expect(timer.state(at: .seconds(749)) == .overdue(.seconds(149)))
    }

    @Test("a 2:30 vuelve solo a cero")
    func resets() {
        var timer = RestTimer()
        timer.tap(at: .seconds(600))
        #expect(timer.state(at: .seconds(750)) == .idle)
        #expect(!timer.isRunning(at: .seconds(750)))
    }

    @Test("un toque mientras cuenta lo para y lo deja a cero")
    func stops() {
        var timer = RestTimer()
        timer.tap(at: .seconds(600))
        timer.tap(at: .seconds(700))
        #expect(timer.state(at: .seconds(700)) == .idle)
        #expect(timer.state(at: .seconds(710)) == .idle)
    }

    @Test("a cero no empieza hasta el siguiente toque")
    func waitsForTap() {
        var timer = RestTimer()
        timer.tap(at: .seconds(600))
        timer.tap(at: .seconds(650))
        timer.tap(at: .seconds(900))
        #expect(timer.state(at: .seconds(930)) == .resting(.seconds(30)))
    }

    @Test("después de volver solo a cero, un toque empieza otro")
    func startsAfterReset() {
        var timer = RestTimer()
        timer.tap(at: .seconds(600))
        timer.tap(at: .seconds(800))
        #expect(timer.state(at: .seconds(810)) == .resting(.seconds(10)))
    }
}

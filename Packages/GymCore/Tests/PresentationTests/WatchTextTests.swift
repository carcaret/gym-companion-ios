import Domain
import Presentation
import Testing

@Suite("Textos del reloj")
struct WatchTextTests {
    @Test("el peso en kilos con coma decimal")
    func weight() {
        #expect(WatchText.weight(62.5) == "62,5 kg")
        #expect(WatchText.weight(80) == "80 kg")
    }

    @Test("sin peso, peso corporal")
    func bodyweight() {
        #expect(WatchText.weight(0) == "Peso corporal")
    }

    @Test("la posición del ejercicio en la rutina")
    func position() {
        #expect(WatchText.position(1, of: 6) == "2/6")
    }

    @Test("el plan de hoy: peso, series y reps objetivo")
    func plan() {
        #expect(WatchText.plan(weight: 62.5, series: 4, reps: 11) == "62,5 kg · 4 × 11")
        #expect(WatchText.plan(weight: 0, series: 3, reps: 8) == "Peso corporal · 3 × 8")
    }

    @Test("una sesión de referencia con su peso y sus reps")
    func reference() {
        #expect(WatchText.reference(weight: 12, reps: [10, 10, nil]) == "12 kg · 10·10·—")
    }

    @Test("el tiempo en minutos y segundos; desde una hora, con las horas")
    func duration() {
        #expect(WatchText.duration(.zero) == "0:00")
        #expect(WatchText.duration(.seconds(65)) == "1:05")
        #expect(WatchText.duration(.seconds(1421)) == "23:41")
        #expect(WatchText.duration(.seconds(3733)) == "1:02:13")
        #expect(WatchText.duration(.milliseconds(59_900)) == "0:59")
    }

    @Test("lo que dice el descanso en cada momento")
    func restLabel() {
        #expect(WatchText.restLabel(.idle) == "toca para descansar")
        #expect(WatchText.restLabel(.resting(.seconds(30))) == "descanso")
        #expect(WatchText.restLabel(.overdue(.seconds(95))) == "a por la siguiente")
    }

    @Test("el pulso redondeado, o una raya sin medida")
    func heartRate() {
        #expect(WatchText.heartRate(127.6) == "128")
        #expect(WatchText.heartRate(nil) == "—")
        #expect(WatchText.averageHeartRate(118.2) == "118 ppm")
        #expect(WatchText.averageHeartRate(nil) == "—")
    }

    @Test("las kcal redondeadas")
    func energy() {
        #expect(WatchText.energy(171.5) == "172")
    }

    @Test("cuántos ejercicios tiene el entreno")
    func exerciseCount() {
        #expect(WatchText.exerciseCount(7) == "7 ejercicios")
        #expect(WatchText.exerciseCount(1) == "1 ejercicio")
    }
}

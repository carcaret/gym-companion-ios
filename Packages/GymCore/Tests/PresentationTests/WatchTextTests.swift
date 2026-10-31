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

    @Test("junto al peso, las reps de la mejor si es del peso de hoy; si no, las objetivo")
    func planReps() {
        func exercise(weight: Double, best: WatchSnapshot.Reference?) -> WatchSnapshot.Exercise {
            WatchSnapshot.Exercise(name: "Press", weight: weight, series: 4, targetReps: 11, skipped: false, best: best, last: nil)
        }
        let best = WatchSnapshot.Reference(date: LocalDate(iso: "2026-09-25")!, weight: 32.5, reps: [11, 11, 10, 8])
        #expect(WatchText.planReps(exercise(weight: 32.5, best: best)) == "11·11·10·8")
        #expect(WatchText.planReps(exercise(weight: 35, best: best)) == "11·11·11·11", "Peso subido: las objetivo")
        #expect(WatchText.planReps(exercise(weight: 35, best: nil)) == "11·11·11·11", "Nunca hecho: las objetivo")
    }

    @Test("la posición del ejercicio en la rutina")
    func position() {
        #expect(WatchText.position(1, of: 6) == "2/6")
    }

    @Test("el tiempo en minutos y segundos, también pasada la hora")
    func duration() {
        #expect(WatchText.duration(.zero) == "0:00")
        #expect(WatchText.duration(.seconds(65)) == "1:05")
        #expect(WatchText.duration(.seconds(1421)) == "23:41")
        #expect(WatchText.duration(.seconds(3733)) == "62:13")
        #expect(WatchText.duration(.seconds(6203)) == "103:23")
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

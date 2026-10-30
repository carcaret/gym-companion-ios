import Domain
import Presentation
import Testing

// Las reps se separan con «·» y la serie vacía es «—» (cambiado con la aprobación del usuario,
// 2026-10-27; en la PWA, «10-8-10» y «10---8»).

@Suite("Textos del reloj")
struct WatchTextTests {
    @Test("las reps de cada serie, separadas por un punto aunque se repitan")
    func reps() {
        #expect(WatchText.reps([12, 12, 11, 10]) == "12·12·11·10")
        #expect(WatchText.reps([14, 4, 11]) == "14·4·11")
        #expect(WatchText.reps([12, 12, 12, 12]) == "12·12·12·12")
    }

    @Test("una serie sin reps de una sesión anterior sale como una raya")
    func emptyRep() {
        #expect(WatchText.reps([12, nil, 10]) == "12·—·10")
    }

    @Test("el peso en kilos con coma decimal")
    func weight() {
        #expect(WatchText.weight(62.5) == "62,5 kg")
        #expect(WatchText.weight(80) == "80 kg")
    }

    @Test("sin peso, peso corporal")
    func bodyweight() {
        #expect(WatchText.weight(0) == "Peso corporal")
    }

    @Test("la fecha de una sesión de referencia: día y mes abreviado")
    func date() {
        #expect(WatchText.date("2026-10-21") == "21 oct")
        #expect(WatchText.date("2026-09-06") == "6 sept")
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

    @Test("el pulso redondeado, o dos rayas sin medida")
    func heartRate() {
        #expect(WatchText.heartRate(127.6) == "128")
        #expect(WatchText.heartRate(nil) == "--")
        #expect(WatchText.averageHeartRate(118.2) == "118 ppm")
        #expect(WatchText.averageHeartRate(nil) == "--")
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

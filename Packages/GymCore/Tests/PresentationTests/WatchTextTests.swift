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

    @Test("la fecha de una sesión anterior: día y mes abreviado")
    func date() {
        #expect(WatchText.date("2026-10-21") == "21 oct")
        #expect(WatchText.date("2026-09-06") == "6 sept")
    }

    @Test("la posición del ejercicio en la rutina")
    func position() {
        #expect(WatchText.position(1, of: 6) == "2/6")
    }
}

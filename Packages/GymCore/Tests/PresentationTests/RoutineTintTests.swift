import Domain
import Presentation
import Testing

// El color de cada rutina: el de `--color-dia1..3` de la PWA (filete de las tarjetas de rutina e
// historial, título y etiqueta del día). La PWA lo ata a la clave DIA1/DIA2/DIA3.
@Suite("Color de cada rutina")
struct RoutineTintTests {
    private let routines: [RoutineID] = ["DIA1", "DIA2", "DIA3"]

    @Test("DIA1, DIA2 y DIA3 tienen el color de su día, como en la PWA")
    func days() {
        #expect(RoutineTint.of("DIA1", in: routines) == .day1)
        #expect(RoutineTint.of("DIA2", in: routines) == .day2)
        #expect(RoutineTint.of("DIA3", in: routines) == .day3)
    }

    @Test("el color no depende del orden de las rutinas")
    func orderDoesNotMatter() {
        #expect(RoutineTint.of("DIA1", in: ["DIA3", "DIA2", "DIA1"]) == .day1)
    }

    @Test("otra rutina toma el color por su posición, de tres en tres")
    func otherRoutines() {
        let routines: [RoutineID] = ["A", "B", "C", "D"]
        #expect(RoutineTint.of("A", in: routines) == .day1)
        #expect(RoutineTint.of("C", in: routines) == .day3)
        #expect(RoutineTint.of("D", in: routines) == .day1)
    }

    @Test("una rutina que ya no existe no tiene color (la PWA tampoco lo pinta)")
    func unknown() {
        #expect(RoutineTint.of("BORRADA", in: routines) == nil)
    }
}

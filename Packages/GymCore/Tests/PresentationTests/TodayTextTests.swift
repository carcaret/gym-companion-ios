import Presentation
import Testing

@Suite("Textos del selector de ejercicios")
struct PickerTextTests {
    @Test("el subtítulo de cambiar dice qué ejercicio se sustituye")
    func swapSubtitle() {
        #expect(TodayText.swapSubtitle("Curl Bíceps") == "En lugar de Curl Bíceps")
    }

    @Test("la segunda línea junta el grupo y las rutinas donde está")
    func detail() {
        #expect(TodayText.pickerDetail(group: "Pecho", routines: ["Día 2", "Día 3"]) == "Pecho · En Día 2, Día 3")
        #expect(TodayText.pickerDetail(group: "Pecho", routines: []) == "Pecho")
        #expect(TodayText.pickerDetail(group: nil, routines: ["Día 2"]) == "En Día 2")
    }

    @Test("sin grupo ni rutinas no hay segunda línea")
    func noDetail() {
        #expect(TodayText.pickerDetail(group: nil, routines: []) == nil)
    }
}

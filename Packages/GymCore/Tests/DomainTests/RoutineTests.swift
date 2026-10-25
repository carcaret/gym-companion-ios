import Domain
import Testing

// Portados de tests/unit/constants.test.js y routine-rename.test.js de la PWA: lo que eran las
// constantes DAY_LABELS y ROUTINE_KEYS son ahora las rutinas por defecto. Las claves de
// localStorage no aplican (los datos los guarda el adaptador de persistencia, #6).

@Suite("constants")
struct ConstantsTests {
    @Test("DAY_LABELS tiene etiquetas Full Body")
    func labels() {
        #expect(Routine.defaults.map(\.name) == ["Full Body - Día 1", "Full Body - Día 2", "Full Body - Día 3"])
    }

    @Test("ROUTINE_KEYS contiene las 3 rutinas")
    func keys() {
        #expect(Routine.defaults.map(\.id) == ["DIA1", "DIA2", "DIA3"])
    }
}

@Suite("DAY_LABELS usa etiquetas Full Body")
struct RoutineLabelTests {
    private func name(_ id: RoutineID) -> String? { Routine.defaults.first { $0.id == id }?.name }

    @Test("DIA1 → Full Body - Día 1")
    func day1() { #expect(name("DIA1") == "Full Body - Día 1") }

    @Test("DIA2 → Full Body - Día 2")
    func day2() { #expect(name("DIA2") == "Full Body - Día 2") }

    @Test("DIA3 → Full Body - Día 3")
    func day3() { #expect(name("DIA3") == "Full Body - Día 3") }

    @Test("no hay etiquetas con nombres de días de la semana")
    func noWeekdays() {
        for routine in Routine.defaults {
            #expect(routine.name.lowercased().wholeMatch(of: /.*(lunes|miércoles|viernes).*/) == nil)
        }
    }

    @Test("no existen claves LUNES, MIERCOLES ni VIERNES")
    func noWeekdayKeys() {
        #expect(name("LUNES") == nil)
        #expect(name("MIERCOLES") == nil)
        #expect(name("VIERNES") == nil)
    }
}

@Suite("ROUTINE_KEYS")
struct RoutineKeysTests {
    @Test("contiene exactamente DIA1, DIA2, DIA3")
    func exact() { #expect(Routine.defaults.map(\.id) == ["DIA1", "DIA2", "DIA3"]) }

    @Test("tiene 3 elementos")
    func three() { #expect(Routine.defaults.count == 3) }
}

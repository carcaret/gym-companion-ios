import Domain
import Presentation
import Testing

// Portados de tests/unit/dates.test.js de la PWA (formatDate, formatDateShort). relativeDate y
// dateBlock no tenían tests: se añaden.

@Suite("formatDate")
struct FormatDateTests {
    @Test("formatea correctamente en español")
    func spanish() {
        // El original solo comprobaba que saliera algo de más de 5 caracteres; aquí, el texto
        // exacto de `toLocaleDateString('es-ES', { weekday, day, month: 'short', year })`.
        #expect(DateText.long("2024-01-15") == "lun, 15 ene 2024")
        #expect(DateText.long("2026-09-06") == "dom, 6 sept 2026")
        #expect(DateText.long("2026-06-20") == "sáb, 20 jun 2026")
    }
}

@Suite("formatDateShort")
struct FormatDateShortTests {
    @Test("fecha con día y mes de un dígito → sin ceros")
    func singleDigits() { #expect(DateText.short("2026-04-05") == "5/4") }

    @Test("fecha con día y mes de dos dígitos")
    func twoDigits() { #expect(DateText.short("2026-12-25") == "25/12") }

    @Test("primer día del año")
    func firstDay() { #expect(DateText.short("2026-01-01") == "1/1") }

    @Test("mes con cero inicial se elimina")
    func leadingZero() { #expect(DateText.short("2026-04-14") == "14/4") }
}

@Suite("relativeDate")
struct RelativeDateTests {
    private let today: LocalDate = "2026-10-25"

    @Test("hoy, ayer y días")
    func days() {
        #expect(DateText.relative("2026-10-25", today: today) == "Hoy")
        #expect(DateText.relative("2026-10-24", today: today) == "Ayer")
        #expect(DateText.relative("2026-10-19", today: today) == "Hace 6 días")
    }

    @Test("semanas, redondeando hacia abajo")
    func weeks() {
        #expect(DateText.relative("2026-10-18", today: today) == "Hace 1 semana")
        #expect(DateText.relative("2026-10-12", today: today) == "Hace 1 semana")
        #expect(DateText.relative("2026-10-11", today: today) == "Hace 2 semanas")
        #expect(DateText.relative("2026-09-25", today: today) == "Hace 4 semanas")
    }

    // Antes seguía sin tope («Hace 52 semanas»), como la PWA (2026-10-27): más allá de un mes ya lo
    // dicen la fecha de la fila y la sección del mes.
    @Test("más de un mes, sin fecha relativa")
    func older() {
        #expect(DateText.relative("2026-09-24", today: today) == nil)
        #expect(DateText.relative("2025-10-25", today: today) == nil)
    }
}

@Suite("monthYear")
struct MonthYearTests {
    @Test("el mes entero y el año, para las secciones del Historial")
    func monthYear() {
        #expect(DateText.monthYear("2026-10-05") == "Octubre de 2026")
        #expect(DateText.monthYear("2025-01-31") == "Enero de 2025")
        #expect(DateText.monthYear("2026-09-01") == "Septiembre de 2026")
    }
}

@Suite("dateBlock")
struct DateBlockTests {
    @Test("día y mes abreviado en mayúsculas")
    func block() {
        #expect(DateText.block("2026-03-05") == DateBlock(day: "5", month: "MAR"))
        #expect(DateText.block("2026-12-31") == DateBlock(day: "31", month: "DIC"))
    }
}

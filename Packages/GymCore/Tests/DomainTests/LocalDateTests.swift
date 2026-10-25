import Domain
import Testing

// Portados de tests/unit/dates.test.js (addDaysStr, getWeekStartStr) de la PWA.

@Suite("addDaysStr")
struct AddDaysTests {
    @Test("suma días positivos")
    func positive() { #expect(LocalDate("2026-04-24").adding(days: 7) == "2026-05-01") }

    @Test("resta días (negativos)")
    func negative() { #expect(LocalDate("2026-04-24").adding(days: -7) == "2026-04-17") }

    @Test("cruza cambio de mes")
    func monthChange() { #expect(LocalDate("2026-01-31").adding(days: 1) == "2026-02-01") }

    @Test("cruza cambio de año")
    func yearChange() { #expect(LocalDate("2025-12-31").adding(days: 1) == "2026-01-01") }

    @Test("cero días devuelve la misma fecha")
    func zero() { #expect(LocalDate("2026-04-24").adding(days: 0) == "2026-04-24") }

    @Test("año bisiesto: 29-feb existe en 2024")
    func leapYear() {
        #expect(LocalDate("2024-02-28").adding(days: 1) == "2024-02-29")
        #expect(LocalDate("2024-02-29").adding(days: 1) == "2024-03-01")
    }
}

@Suite("getWeekStartStr")
struct WeekStartTests {
    @Test("lunes devuelve el mismo lunes")
    func monday() { #expect(LocalDate("2026-04-20").weekStart == "2026-04-20") }

    @Test("miércoles devuelve el lunes anterior")
    func wednesday() { #expect(LocalDate("2026-04-22").weekStart == "2026-04-20") }

    @Test("domingo devuelve el lunes anterior")
    func sunday() { #expect(LocalDate("2026-04-26").weekStart == "2026-04-20") }

    @Test("sábado devuelve el lunes de esa semana")
    func saturday() { #expect(LocalDate("2026-04-25").weekStart == "2026-04-20") }

    @Test("cruza cambio de mes hacia atrás")
    func monthBack() { #expect(LocalDate("2026-05-01").weekStart == "2026-04-27") }

    @Test("cruza cambio de año hacia atrás")
    func yearBack() { #expect(LocalDate("2026-01-01").weekStart == "2025-12-29") }
}

/// Lo que en la PWA era un `string` "YYYY-MM-DD" es aquí un tipo: estas reglas sustituyen a las
/// comprobaciones de formato que la PWA hacía con expresiones regulares.
@Suite("LocalDate")
struct LocalDateTests {
    @Test("se lee y se escribe como YYYY-MM-DD")
    func isoRoundTrip() {
        #expect(LocalDate(iso: "2026-03-05")?.iso == "2026-03-05")
        #expect(LocalDate(iso: "2026-03-05") == LocalDate(year: 2026, month: 3, day: 5))
    }

    @Test("rechaza textos que no son una fecha real")
    func invalid() {
        for text in ["", "2026-3-5", "2026-02-30", "2026-13-01", "26-03-05", "2026-03-05T00:00", "abcd-ef-gh"] {
            #expect(LocalDate(iso: text) == nil, "\(text)")
        }
    }

    @Test("ordena por fecha")
    func ordering() {
        #expect(LocalDate("2025-12-31") < LocalDate("2026-01-01"))
        #expect(LocalDate("2026-02-01") > LocalDate("2026-01-31"))
    }

    @Test("días entre dos fechas")
    func daysBetween() {
        #expect(LocalDate("2026-06-05").days(until: "2026-06-19") == 14)
        #expect(LocalDate("2026-06-19").days(until: "2026-06-05") == -14)
        #expect(LocalDate("2024-02-28").days(until: "2024-03-01") == 2)
    }

    @Test("día de la semana, con el lunes como primero")
    func weekday() {
        #expect(LocalDate("2026-04-20").weekday == .monday)
        #expect(LocalDate("2026-04-26").weekday == .sunday)
        #expect(LocalDate("2026-01-01").weekday == .thursday)
    }
}

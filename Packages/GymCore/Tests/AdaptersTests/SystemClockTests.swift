import Adapters
import Domain
import Foundation
import Testing

@Suite("todayStr")
struct SystemClockTests {
    @Test("devuelve formato YYYY-MM-DD")
    func format() {
        let iso = SystemClock().today().iso
        #expect(iso.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil)
    }

    @Test("es el día local, no el de UTC")
    func localDay() throws {
        // Las 23:30 UTC del 31 de diciembre son ya las 00:30 del 1 de enero en Madrid. La PWA
        // usaba el día UTC (toISOString), así que pasada la medianoche apuntaba el entreno al día
        // anterior.
        let madrid = try #require(TimeZone(identifier: "Europe/Madrid"))
        let instant = Date(timeIntervalSince1970: 1_767_223_800) // 2025-12-31T23:30:00Z
        #expect(SystemClock(timeZone: madrid, now: { instant }).today() == LocalDate(year: 2026, month: 1, day: 1))
        #expect(SystemClock(timeZone: .gmt, now: { instant }).today() == LocalDate(year: 2025, month: 12, day: 31))
    }
}

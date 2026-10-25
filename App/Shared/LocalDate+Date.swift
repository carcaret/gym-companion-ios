import Domain
import Foundation

/// El paso entre el día del modelo (`LocalDate`) y la fecha de SwiftUI (`Date`), en el calendario
/// gregoriano y la zona horaria del iPhone. Solo para las vistas (selectores de fecha, gráficas).
extension LocalDate {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Las 12:00 de ese día (lejos de los cambios de hora).
    var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    init(_ date: Date) {
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self = LocalDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1) ?? LocalDate(daysSinceEpoch: 0)
    }
}

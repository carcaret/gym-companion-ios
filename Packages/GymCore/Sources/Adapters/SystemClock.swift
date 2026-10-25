import Application
import Domain
import Foundation

/// Reloj del sistema: el día de hoy según la zona horaria del aparato.
public struct SystemClock: Clock {
    private let timeZone: TimeZone
    private let now: @Sendable () -> Date

    public init(timeZone: TimeZone = .current, now: @escaping @Sendable () -> Date = Date.init) {
        self.timeZone = timeZone
        self.now = now
    }

    public func today() -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        guard let date = LocalDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0) else {
            preconditionFailure("El calendario gregoriano ha dado una fecha imposible: \(parts)")
        }
        return date
    }
}

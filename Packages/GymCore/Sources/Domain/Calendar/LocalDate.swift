/// Un día del calendario gregoriano, sin hora ni zona horaria: la fecha de una sesión.
///
/// Sustituye a los `string` "YYYY-MM-DD" de la PWA. Se guarda como número de días desde el
/// 1970-01-01, así que sumar días, comparar o calcular el lunes de la semana no depende de la
/// zona horaria ni de los cambios de hora (la PWA lo resolvía parseando a las 12:00 UTC).
public struct LocalDate: Hashable, Comparable, Sendable {
    /// Días transcurridos desde el 1970-01-01 (negativo antes).
    public let daysSinceEpoch: Int

    public init(daysSinceEpoch: Int) {
        self.daysSinceEpoch = daysSinceEpoch
    }

    /// `nil` si la combinación no existe (p. ej. 30 de febrero).
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...Self.daysIn(month: month, year: year)).contains(day) else { return nil }
        daysSinceEpoch = Self.days(year: year, month: month, day: day)
    }

    /// Lee "YYYY-MM-DD"; `nil` si el texto no tiene exactamente ese formato o la fecha no existe.
    public init?(iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public var year: Int { civil.year }
    public var month: Int { civil.month }
    public var day: Int { civil.day }

    /// "YYYY-MM-DD".
    public var iso: String {
        let (year, month, day) = civil
        return "\(Self.padded(year, 4))-\(Self.padded(month, 2))-\(Self.padded(day, 2))"
    }

    public func adding(days: Int) -> LocalDate {
        LocalDate(daysSinceEpoch: daysSinceEpoch + days)
    }

    /// Días desde `self` hasta `other` (negativo si `other` es anterior).
    public func days(until other: LocalDate) -> Int {
        other.daysSinceEpoch - daysSinceEpoch
    }

    public var weekday: Weekday {
        // El 1970-01-01 fue jueves.
        let index = ((daysSinceEpoch + 3) % 7 + 7) % 7
        return Weekday.allCases[index]
    }

    /// El lunes de la semana (las semanas van de lunes a domingo).
    public var weekStart: LocalDate {
        adding(days: -Weekday.allCases.firstIndex(of: weekday)!)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        lhs.daysSinceEpoch < rhs.daysSinceEpoch
    }

    // MARK: - Calendario civil (algoritmos de Howard Hinnant, "chrono-compatible low-level date algorithms")

    private static func days(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private var civil: (year: Int, month: Int, day: Int) {
        let z = daysSinceEpoch + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    private static func isLeap(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    private static func padded(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}

/// Días de la semana, empezando por el lunes.
public enum Weekday: CaseIterable, Sendable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

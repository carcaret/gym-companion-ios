import Domain

/// Día y mes para el bloque de fecha del Historial.
public struct DateBlock: Hashable, Sendable {
    public let day: String
    public let month: String

    public init(day: String, month: String) {
        self.day = day
        self.month = month
    }
}

/// Fechas en español.
public enum DateText {
    private static let weekdays = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
    private static let months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic"]

    /// "lun, 15 ene 2024" (el `toLocaleDateString('es-ES', …)` de la PWA).
    public static func long(_ date: LocalDate) -> String {
        "\(weekdays[date.weekday.rawValue]), \(date.day) \(months[date.month - 1]) \(date.year)"
    }

    /// "5/4": día y mes sin ceros.
    public static func short(_ date: LocalDate) -> String {
        "\(date.day)/\(date.month)"
    }

    /// "Hoy", "Ayer", "Hace 3 días", "Hace 1 semana", "Hace 5 semanas".
    public static func relative(_ date: LocalDate, today: LocalDate) -> String {
        let days = date.days(until: today)
        switch days {
        case 0: return "Hoy"
        case 1: return "Ayer"
        case ..<7: return "Hace \(days) días"
        case ..<14: return "Hace 1 semana"
        default: return "Hace \(days / 7) semanas"
        }
    }

    /// Día del mes y mes abreviado en mayúsculas ("5", "MAR").
    public static func block(_ date: LocalDate) -> DateBlock {
        DateBlock(day: String(date.day), month: String(months[date.month - 1].prefix(3)).uppercased())
    }
}

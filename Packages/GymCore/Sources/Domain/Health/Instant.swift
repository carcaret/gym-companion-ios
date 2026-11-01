/// Un momento concreto y la diferencia con UTC que tenía el iPhone entonces: cuándo se tomó una
/// medida de Salud. La hora local importa (las medidas de la mañana no son las de la tarde), y en
/// España cambia con el horario de verano.
public struct Instant: Hashable, Comparable, Sendable {
    /// Segundos desde el 1970-01-01 00:00:00 UTC.
    public let secondsSinceEpoch: Int
    /// Lo que la hora local va por delante de UTC, en segundos (+3600 en invierno en España).
    public let utcOffsetSeconds: Int

    public init(secondsSinceEpoch: Int, utcOffsetSeconds: Int) {
        self.secondsSinceEpoch = secondsSinceEpoch
        self.utcOffsetSeconds = utcOffsetSeconds
    }

    /// El momento de ese día a esa hora local. `nil` si la hora no existe.
    public init?(_ date: LocalDate, hour: Int, minute: Int, second: Int = 0, utcOffsetSeconds: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute), (0..<60).contains(second) else { return nil }
        let local = date.daysSinceEpoch * Self.secondsPerDay + hour * 3600 + minute * 60 + second
        self.init(secondsSinceEpoch: local - utcOffsetSeconds, utcOffsetSeconds: utcOffsetSeconds)
    }

    /// El día en la hora local.
    public var localDate: LocalDate {
        LocalDate(daysSinceEpoch: Self.floorDivision(localSeconds, Self.secondsPerDay))
    }

    /// La hora local: horas, minutos y segundos.
    public var localTime: (hour: Int, minute: Int, second: Int) {
        let seconds = localSeconds - localDate.daysSinceEpoch * Self.secondsPerDay
        return (seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }

    /// Por el momento; el mismo momento con otra diferencia con UTC va detrás.
    public static func < (lhs: Instant, rhs: Instant) -> Bool {
        (lhs.secondsSinceEpoch, lhs.utcOffsetSeconds) < (rhs.secondsSinceEpoch, rhs.utcOffsetSeconds)
    }

    private var localSeconds: Int { secondsSinceEpoch + utcOffsetSeconds }

    private static let secondsPerDay = 86_400

    private static func floorDivision(_ value: Int, _ divisor: Int) -> Int {
        let quotient = value / divisor
        return value % divisor < 0 ? quotient - 1 : quotient
    }
}

/// Cuándo es una medida: un momento, o un día entero cuando quien la escribió no dio la hora
/// (MacroFactor guarda el peso de 0:00 a 23:59).
public enum MeasurementTime: Hashable, Comparable, Sendable {
    case instant(Instant)
    case day(LocalDate)

    /// Un intervalo de Salud: un solo momento si empieza y acaba a la vez; si no, el día en que
    /// empieza.
    public init(start: Instant, end: Instant) {
        self = start == end ? .instant(start) : .day(start.localDate)
    }

    /// El día local.
    public var localDate: LocalDate {
        switch self {
        case .instant(let instant): instant.localDate
        case .day(let day): day
        }
    }

    /// Por días; dentro de un día, el día entero antes que sus momentos.
    public static func < (lhs: MeasurementTime, rhs: MeasurementTime) -> Bool {
        switch (lhs, rhs) {
        case (.instant(let a), .instant(let b)): a < b
        case (.day(let a), .day(let b)): a < b
        case (.day(let a), .instant(let b)): a <= b.localDate
        case (.instant(let a), .day(let b)): a.localDate < b
        }
    }
}

/// Identificador estable de un ejercicio ("press_banca"). Nunca cambia al renombrar: es lo que
/// enlaza el historial con el catálogo.
public struct ExerciseID: Hashable, Comparable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var description: String { rawValue }

    public static func < (lhs: ExerciseID, rhs: ExerciseID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

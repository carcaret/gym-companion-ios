/// Grupo muscular, guardado sin tildes ("biceps"); la ortografía bonita la pone la interfaz.
///
/// Es un conjunto abierto: los datos pueden traer un grupo que no está entre los conocidos (y la
/// PWA lo conserva), pero el catálogo solo deja elegir los de `MuscleGroup.all`.
public struct MuscleGroup: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var description: String { rawValue }

    public static let pecho: MuscleGroup = "pecho"
    public static let espalda: MuscleGroup = "espalda"
    public static let hombros: MuscleGroup = "hombros"
    public static let biceps: MuscleGroup = "biceps"
    public static let triceps: MuscleGroup = "triceps"
    public static let piernas: MuscleGroup = "piernas"
    public static let core: MuscleGroup = "core"

    /// Los grupos que se pueden elegir, en el orden de la lista del catálogo: torso de arriba
    /// abajo, brazos y core al final. (`GRUPOS` en la PWA.)
    public static let all: [MuscleGroup] = [.pecho, .espalda, .hombros, .biceps, .triceps, .piernas, .core]

    public var isKnown: Bool { Self.all.contains(self) }
}

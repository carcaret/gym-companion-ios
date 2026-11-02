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
    public static let cuadriceps: MuscleGroup = "cuadriceps"
    /// Femoral y glúteo, la parte de atrás de la pierna: van juntos porque casi todo lo que carga
    /// uno carga el otro (peso muerto rumano, hip thrust, extensiones de espalda).
    public static let femoralGluteo: MuscleGroup = "femoral_gluteo"
    public static let gemelos: MuscleGroup = "gemelos"
    public static let core: MuscleGroup = "core"
    /// La pierna entera, como era antes de partirla en cuádriceps, femoral y glúteo, y gemelos
    /// (decisión del usuario, 2026-11-02: junta, 11 series por semana parecían bien y eran unas 6
    /// en cada mitad). Ya no se elige; la pueden traer datos viejos.
    public static let piernas: MuscleGroup = "piernas"

    /// Los grupos que se pueden elegir, en el orden de la lista del catálogo: torso de arriba
    /// abajo, brazos, piernas y core al final. (`GRUPOS` en la PWA, con la pierna partida.)
    public static let all: [MuscleGroup] = [.pecho, .espalda, .hombros, .biceps, .triceps, .cuadriceps, .femoralGluteo, .gemelos, .core]

    public var isKnown: Bool { Self.all.contains(self) }
}

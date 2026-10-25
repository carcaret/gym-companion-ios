/// Un ejercicio del catálogo.
public struct Exercise: Hashable, Sendable {
    public let id: ExerciseID
    public var name: String
    /// Grupo muscular primario; `nil` = sin clasificar.
    public var group: MuscleGroup?
    /// Músculos que trabajan de forma indirecta. `nil` = nadie los ha editado nunca (se usan los
    /// de `SecondaryGroups.defaults`); `[]` = decisión del usuario de que no aporta a nada.
    public var secondaryGroups: [MuscleGroup]?

    public init(id: ExerciseID, name: String, group: MuscleGroup? = nil, secondaryGroups: [MuscleGroup]? = nil) {
        self.id = id
        self.name = name
        self.group = group
        self.secondaryGroups = secondaryGroups
    }
}

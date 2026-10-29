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

extension Exercise {
    /// Su grupo, solo si es uno de los que se pueden elegir (`MuscleGroup.all`).
    public var knownGroup: MuscleGroup? {
        group.flatMap { $0.isKnown ? $0 : nil }
    }
}

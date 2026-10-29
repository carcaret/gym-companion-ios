/// Por qué no se puede editar un ejercicio.
public enum CatalogError: Error, Hashable, Sendable {
    case notFound
    case emptyName
    case invalidGroup
}

/// Los ejercicios de un grupo, para la lista del catálogo.
public struct CatalogGroup: Hashable, Sendable {
    /// `nil` = sin grupo (o con un grupo que no es de los conocidos).
    public let group: MuscleGroup?
    /// Ordenados por nombre, con los secundarios ya resueltos.
    public let exercises: [Exercise]
}

/// Todos los ejercicios, entrenados o no.
public struct Catalog: Hashable, Sendable {
    private var exercises: [ExerciseID: Exercise]

    public init(_ exercises: some Sequence<Exercise>) {
        self.exercises = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    public subscript(id: ExerciseID) -> Exercise? { exercises[id] }

    public var ids: [ExerciseID] { exercises.keys.sorted() }

    public var all: [Exercise] { ids.compactMap { exercises[$0] } }

    /// El nombre del ejercicio, o su id si no está en el catálogo (o no tiene nombre).
    public func name(of id: ExerciseID) -> String {
        guard let name = exercises[id]?.name, !name.isEmpty else { return id.rawValue }
        return name
    }

    /// El catálogo agrupado por grupo primario, en el orden de `MuscleGroup.all` y los sin grupo
    /// al final, opcionalmente filtrado por nombre (sin tildes ni mayúsculas). No mira el
    /// historial: un ejercicio nunca entrenado también se puede renombrar y clasificar.
    public func groups(matching query: String = "") -> [CatalogGroup] {
        let needle = query.trimmingWhitespace().searchFolded
        var byGroup: [MuscleGroup?: [Exercise]] = [:]
        for id in ids {
            guard var exercise = exercises[id] else { continue }
            exercise.name = name(of: id)
            if !needle.isEmpty, !exercise.name.searchFolded.contains(needle) { continue }
            exercise.secondaryGroups = SecondaryGroups.resolve(exercise, id: id)
            let group = exercise.knownGroup
            byGroup[group, default: []].append(exercise)
        }
        let order: [MuscleGroup?] = MuscleGroup.all.map { $0 } + [nil]
        return order.compactMap { group in
            byGroup[group].map { CatalogGroup(group: group, exercises: $0.sorted { SpanishCollation.precedes($0.name, $1.name) }) }
        }
    }

    /// Edita nombre, grupo primario y secundarios. El id no cambia nunca: es lo que enlaza el
    /// historial con el ejercicio. El primario no puede ser también secundario (contaría dos
    /// veces el mismo trabajo) y los secundarios desconocidos o repetidos se descartan.
    public mutating func update(_ id: ExerciseID, name: String, group: MuscleGroup?, secondaryGroups: [MuscleGroup]) throws(CatalogError) {
        guard var exercise = exercises[id] else { throw .notFound }
        let trimmed = name.trimmingWhitespace()
        guard !trimmed.isEmpty else { throw .emptyName }
        if let group, !group.isKnown { throw .invalidGroup }
        var cleaned: [MuscleGroup] = []
        for secondary in secondaryGroups where secondary.isKnown && secondary != group && !cleaned.contains(secondary) {
            cleaned.append(secondary)
        }
        exercise.name = trimmed
        exercise.group = group
        exercise.secondaryGroups = cleaned
        exercises[id] = exercise
    }
}

/// Series de un ejercicio dentro de un grupo.
public struct ExerciseSets: Hashable, Sendable {
    public let name: String
    public let sets: Int
    public let sessions: Int
    public let setsPerWeek: Double
}

/// Trabajo indirecto que un ejercicio aporta a un grupo (en series, a `indirectFraction` cada una).
public struct IndirectSets: Hashable, Sendable {
    public let name: String
    public let sets: Double

    public init(name: String, sets: Double) {
        self.name = name
        self.sets = sets
    }
}

/// Series de un grupo muscular en una ventana de semanas (la sección Grupos musculares de Progreso).
///
/// Se cuentan series y no volumen en kg·rep: el volumen premia lo que se carga pesado y hace
/// incomparables los grupos entre sí. Aviso conocido: brazos y core salen infracontados.
public struct GroupSets: Hashable, Sendable {
    /// `nil` = ejercicios sin grupo.
    public let group: MuscleGroup?
    /// Series directas.
    public let sets: Int
    public let indirectSets: Double
    public var totalSets: Double { Double(sets) + indirectSets }
    /// Sesiones con trabajo directo.
    public let sessions: Int
    public let setsPerWeek: Double
    /// De más a menos series.
    public let exercises: [ExerciseSets]
    /// De más a menos series.
    public let indirect: [IndirectSets]

    /// Series por semana, directas e indirectas: lo que se compara con la franja.
    public func totalPerWeek(weeks: Int) -> Double { totalSets / Double(weeks) }

    /// Franja de referencia, en series por músculo y semana: 10–20, lo habitual para ganar
    /// músculo (el metaanálisis de Schoenfeld de 2017: 10 o más por semana, mejor que menos de 5).
    /// La PWA usaba 4–10, que es más bien lo justo para mantener, y daba por «te pasas» lo que
    /// era ir en lo mínimo (decisión del usuario, 2026-11-02).
    public static let weeklyReferenceRange = 10...20

    /// La escala común de todas las barras, en series por semana, para que la franja caiga en el
    /// mismo sitio en cada una: el grupo mayor redondeado a la media decena de arriba, y nunca menos
    /// de la franja y otra media decena, para que su límite de arriba no quede en el borde.
    public static func scale(largestPerWeek: Double, reference: ClosedRange<Int> = weeklyReferenceRange) -> Double {
        max((largestPerWeek / 5).rounded(.up) * 5, Double(reference.upperBound + 5))
    }
}

extension TrainingData {
    /// Series por grupo muscular en las `weeks` semanas anteriores a `anchor` (incluidas las dos
    /// puntas), sin las sesiones saltadas, de más a menos series totales.
    public func groupSets(anchor: LocalDate, weeks: Int = ProgressWindow.weeks) -> [GroupSets] {
        struct Tally {
            var sets = 0, sessions = 0, indirectSets = 0.0
            // Por id: dos ejercicios con el mismo nombre son dos filas, no una suma.
            var exercises: [ExerciseID: (sets: Int, sessions: Int)] = [:]
            var indirect: [ExerciseID: Double] = [:]
        }
        let from = anchor.adding(days: -weeks * 7)
        var tallies: [MuscleGroup?: Tally] = [:]

        for session in history where (from...anchor).contains(session.date) {
            for log in session.logs where !log.skipped {
                let exercise = catalog[log.exerciseID]
                var direct = tallies[exercise?.group, default: Tally()]
                direct.sets += log.series
                direct.sessions += 1
                direct.exercises[log.exerciseID, default: (0, 0)].sets += log.series
                direct.exercises[log.exerciseID, default: (0, 0)].sessions += 1
                tallies[exercise?.group] = direct
                for secondary in SecondaryGroups.resolve(exercise, id: log.exerciseID) {
                    let contribution = Double(log.series) * SecondaryGroups.indirectFraction
                    tallies[secondary, default: Tally()].indirectSets += contribution
                    tallies[secondary, default: Tally()].indirect[log.exerciseID, default: 0] += contribution
                }
            }
        }

        let perWeek = Double(weeks)
        return tallies.map { group, tally in
            GroupSets(
                group: group, sets: tally.sets, indirectSets: tally.indirectSets, sessions: tally.sessions,
                setsPerWeek: Double(tally.sets) / perWeek,
                exercises: tally.exercises
                    .map { ExerciseSets(name: catalog.name(of: $0.key), sets: $0.value.sets, sessions: $0.value.sessions, setsPerWeek: Double($0.value.sets) / perWeek) }
                    .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : SpanishCollation.precedes($0.name, $1.name) },
                indirect: tally.indirect.map { IndirectSets(name: catalog.name(of: $0.key), sets: $0.value) }
                    .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : SpanishCollation.precedes($0.name, $1.name) }
            )
        }.sorted { a, b in
            // A igualdad de series, por grupo; los sin grupo, delante (en la PWA, "(sin grupo)" iba
            // antes que las letras).
            guard a.totalSets == b.totalSets else { return a.totalSets > b.totalSets }
            switch (a.group, b.group) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case let (a?, b?): return SpanishCollation.precedes(a.rawValue, b.rawValue)
            }
        }
    }
}

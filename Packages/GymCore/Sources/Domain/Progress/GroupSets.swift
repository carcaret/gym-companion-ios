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

/// Series de un grupo muscular en una ventana de semanas (tarjeta Grupos de Estadísticas).
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

    /// Franja de referencia de la literatura: 4–10 series por músculo y semana.
    public static let weeklyReferenceRange = 4...10

    /// La franja de referencia para una ventana de `weeks` semanas, en series totales.
    public static func referenceRange(weeks: Int) -> ClosedRange<Int> {
        weeklyReferenceRange.lowerBound * weeks...weeklyReferenceRange.upperBound * weeks
    }
}

extension TrainingData {
    /// Series por grupo muscular en las `weeks` semanas anteriores a `anchor` (incluidas las dos
    /// puntas), sin las sesiones saltadas, de más a menos series totales.
    public func groupSets(anchor: LocalDate, weeks: Int = 8) -> [GroupSets] {
        struct Tally {
            var sets = 0, sessions = 0, indirectSets = 0.0
            var exercises: [String: (sets: Int, sessions: Int)] = [:]
            var indirect: [String: Double] = [:]
        }
        let from = anchor.adding(days: -weeks * 7)
        var tallies: [MuscleGroup?: Tally] = [:]

        for session in history where (from...anchor).contains(session.date) {
            for log in session.logs where !log.skipped {
                let exercise = catalog[log.exerciseID]
                let name = catalog.name(of: log.exerciseID)
                tallies[exercise?.group, default: Tally()].sets += log.series
                tallies[exercise?.group, default: Tally()].sessions += 1
                tallies[exercise?.group, default: Tally()].exercises[name, default: (0, 0)].sets += log.series
                tallies[exercise?.group, default: Tally()].exercises[name, default: (0, 0)].sessions += 1
                for secondary in SecondaryGroups.resolve(exercise, id: log.exerciseID) {
                    let contribution = Double(log.series) * SecondaryGroups.indirectFraction
                    tallies[secondary, default: Tally()].indirectSets += contribution
                    tallies[secondary, default: Tally()].indirect[name, default: 0] += contribution
                }
            }
        }

        let perWeek = Double(weeks)
        return tallies.map { group, tally in
            GroupSets(
                group: group, sets: tally.sets, indirectSets: tally.indirectSets, sessions: tally.sessions,
                setsPerWeek: Double(tally.sets) / perWeek,
                exercises: tally.exercises
                    .map { ExerciseSets(name: $0.key, sets: $0.value.sets, sessions: $0.value.sessions, setsPerWeek: Double($0.value.sets) / perWeek) }
                    .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : SpanishCollation.precedes($0.name, $1.name) },
                indirect: tally.indirect.map { IndirectSets(name: $0.key, sets: $0.value) }
                    .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : SpanishCollation.precedes($0.name, $1.name) }
            )
        }.sorted { a, b in
            // A igualdad de series, por grupo; los sin grupo, como "(sin grupo)" en la PWA: delante.
            a.totalSets != b.totalSets ? a.totalSets > b.totalSets
                : SpanishCollation.precedes(a.group?.rawValue ?? "(", b.group?.rawValue ?? "(")
        }
    }
}

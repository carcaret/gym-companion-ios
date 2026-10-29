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
/// La ventana de Progreso: las series y el progreso de cada ejercicio, en las últimas 8 semanas.
public enum ProgressWindow {
    public static let weeks = 8
}

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

    /// La escala común de todas las barras, en decenas, para que la franja caiga en el mismo sitio
    /// en cada una: lo más alto de `largest` y de la franja, y nunca menos de 10.
    public static func scale(largest: Double, reference: ClosedRange<Int>) -> Double {
        max((max(largest, Double(reference.upperBound)) / 10).rounded(.up) * 10, 10)
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

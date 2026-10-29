import Application
import Domain
import Observation
import Presentation

/// La pestaña Progreso (`views/estadisticas.js` de la PWA): cómo va cada ejercicio de las rutinas
/// y cuántas series recibe cada grupo muscular en las últimas 8 semanas.
@MainActor
@Observable
public final class ProgressModel {
    public static let weeks = 8

    public struct ExerciseRow: Hashable, Sendable, Identifiable {
        public var id: ExerciseID { exerciseID }
        public let exerciseID: ExerciseID
        public let name: String
        /// "18 kg"; sin peso, nada.
        public let weight: String?
        public let phrase: String
        public let status: ProgressStatus
        /// Las reps de las últimas sesiones ("11-11-10").
        public let recentReps: [String]
        /// "Ver en Gráficas", solo si hay histórico que dibujar.
        public let canOpenCharts: Bool
        public let isOpen: Bool
    }

    public struct GroupRow: Hashable, Sendable, Identifiable {
        public var id: String { name }
        public let name: String
        public let sets: Int
        public let indirectSets: Double
        /// Series totales redondeadas.
        public let total: Int
        /// "Remo" y "12 · 4" (series · sesiones).
        public let exercises: [(name: String, value: String)]
        public let indirect: [(name: String, value: String)]
        public let isOpen: Bool

        public static func == (lhs: GroupRow, rhs: GroupRow) -> Bool {
            lhs.name == rhs.name && lhs.sets == rhs.sets && lhs.indirectSets == rhs.indirectSets && lhs.isOpen == rhs.isOpen
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
    }

    /// La tarjeta Ejercicios enseña todo, no solo los estancados.
    public private(set) var isExpanded = false
    private var openRows: Set<ExerciseID> = []
    private var openGroups: Set<String> = []
    /// Las gráficas de un ejercicio, empujadas dentro de Progreso; `nil` = Progreso.
    public private(set) var charts: ChartsModel?

    private let app: AppModel
    private let clock: any Clock

    public init(app: AppModel, clock: any Clock) {
        self.app = app
        self.clock = clock
    }

    private var data: TrainingData { app.data ?? TrainingData() }

    // MARK: - Ejercicios

    /// Los ejercicios de las rutinas (sin repetir), estancados primero y sin recorrido al final.
    public var allRows: [ExerciseRow] {
        var seen = Set<ExerciseID>()
        let ids = data.routines.flatMap(\.exerciseIDs).filter { seen.insert($0).inserted }
        return data.progressRows(for: ids, anchor: clock.today(), weeks: Self.weeks).map { progress in
            ExerciseRow(
                exerciseID: progress.exerciseID, name: data.catalog.name(of: progress.exerciseID),
                weight: progress.weight > 0 ? "\(LogText.kilograms(progress.weight)) kg" : nil,
                phrase: ProgressText.phrase(progress), status: progress.status,
                recentReps: progress.recentReps.map { LogText.reps($0) },
                canOpenCharts: progress.status != .noTrack, isOpen: openRows.contains(progress.exerciseID)
            )
        }
    }

    /// Si hay algo que comparar: con todo sin recorrido (o sin entrenos), la pantalla dice cuál es el
    /// siguiente paso (repaso de la HIG, 2026-10-28).
    public var hasProgress: Bool {
        allRows.contains { $0.status != .noTrack }
    }

    /// Plegada, solo los estancados (que responden "¿qué toco?"); desplegada, todos.
    public var visibleRows: [ExerciseRow] {
        isExpanded ? allRows : allRows.filter { $0.status == .stalled }
    }

    public var exercisesSubtitle: String {
        let rows = allRows
        return ProgressText.exercisesSubtitle(stalled: rows.filter { $0.status == .stalled }.count, total: rows.count,
                                           progressing: rows.filter { $0.status == .progressing }.count)
    }

    public func toggleExpanded() {
        isExpanded.toggle()
    }

    public func toggleRow(_ exercise: ExerciseID) {
        if openRows.contains(exercise) { openRows.remove(exercise) } else { openRows.insert(exercise) }
    }

    /// "Ver en Gráficas": las gráficas del ejercicio, empujadas dentro de Progreso. Son otras que
    /// las de la pestaña Gráficas, que conserva su rango y su ejercicio.
    public func openCharts(_ exercise: ExerciseID) {
        let charts = ChartsModel(app: app, clock: clock)
        charts.choose(exercise)
        self.charts = charts
    }

    /// Volver de las gráficas (la flecha de iOS o deslizar).
    public func closeCharts() {
        charts = nil
    }

    /// Tocar otra vez la pestaña: Progreso, sin las gráficas empujadas.
    public func reselect() {
        closeCharts()
    }

    // MARK: - Grupos

    public var groups: [GroupRow] {
        data.groupSets(anchor: clock.today(), weeks: Self.weeks).map { group in
            let name = GroupText.name(group.group)
            return GroupRow(
                name: name, sets: group.sets, indirectSets: group.indirectSets, total: Int(jsRound(group.totalSets)),
                exercises: group.exercises.map { ($0.name, "\($0.sets) · \($0.sessions)") },
                indirect: group.indirect.map { ($0.name, ProgressText.indirectSets($0.sets)) },
                isOpen: openGroups.contains(name)
            )
        }
    }

    /// La franja de referencia (4–10 series por semana) en series de toda la ventana.
    public var referenceBand: ClosedRange<Int> { GroupSets.referenceRange(weeks: Self.weeks) }

    /// Escala absoluta compartida por todas las barras, en decenas (si cada barra se escalara a su
    /// manera, la franja caería en un sitio distinto en cada una y no significaría nada).
    public var scale: Double {
        let largest = groups.map { Double($0.sets) + $0.indirectSets }.max() ?? 0
        return max((max(largest, Double(referenceBand.upperBound)) / 10).rounded(.up) * 10, 10)
    }

    public func toggleGroup(_ name: String) {
        if openGroups.contains(name) { openGroups.remove(name) } else { openGroups.insert(name) }
    }
}

import Application
import Domain
import Observation
import Presentation

/// La pestaña Progreso (`views/estadisticas.js` de la PWA): cómo va cada ejercicio de las rutinas
/// y cuántas series recibe cada grupo muscular en las últimas 8 semanas.
@MainActor
@Observable
public final class ProgressModel {
    public static let weeks = ProgressWindow.weeks

    public struct ExerciseRow: Hashable, Sendable, Identifiable {
        public var id: ExerciseID { exerciseID }
        public let exerciseID: ExerciseID
        public let name: String
        /// "18 kg"; sin peso, o si la frase ya lo dice, nada.
        public let weight: String?
        public let phrase: String
        public let status: ProgressStatus
        /// Las últimas sesiones, una por línea, la más antigua primero.
        public let recentSessions: [RecentSessionRow]
        /// "Ver en Gráficas", solo si hay histórico que dibujar.
        public let canOpenCharts: Bool
        public let isOpen: Bool
    }

    /// Una de las últimas sesiones de un ejercicio: "5 oct" y "10·10·10".
    public struct RecentSessionRow: Hashable, Sendable {
        public let date: String
        public let reps: String
    }

    /// Una línea del desglose de un grupo: "Remo" y "12 · 4" (series · sesiones), o sus series
    /// indirectas.
    public struct GroupDetail: Hashable, Sendable {
        public let name: String
        public let value: String
    }

    public struct GroupRow: Hashable, Sendable, Identifiable {
        public var id: String { name }
        public let name: String
        /// Series por semana, directas e indirectas, en la escala de `scale`.
        public let directPerWeek: Double
        public let indirectPerWeek: Double
        /// "12,8": las dos juntas.
        public let perWeek: String
        public let exercises: [GroupDetail]
        public let indirect: [GroupDetail]
        public let isOpen: Bool
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

    private var data: TrainingData { app.current }

    // MARK: - Ejercicios

    /// Los ejercicios de las rutinas (sin repetir), estancados primero y sin recorrido al final.
    public var allRows: [ExerciseRow] {
        return data.progressRows(for: data.routines.allExerciseIDs, anchor: clock.today(), weeks: Self.weeks).map { progress in
            ExerciseRow(
                exerciseID: progress.exerciseID, name: data.catalog.name(of: progress.exerciseID),
                weight: ProgressText.weight(progress), phrase: ProgressText.phrase(progress), status: progress.status,
                recentSessions: progress.recentSessions.map { RecentSessionRow(date: DateText.dayMonth($0.date), reps: LogText.reps($0.reps)) },
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
        openRows.toggle(exercise)
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

    /// De más a menos series. Las barras van en series por semana; el desglose, en las de toda la
    /// ventana, con sus sesiones.
    public var groups: [GroupRow] {
        let weeks = Double(Self.weeks)
        return data.groupSets(anchor: clock.today(), weeks: Self.weeks).map { group in
            let name = GroupText.name(group.group)
            return GroupRow(
                name: name, directPerWeek: Double(group.sets) / weeks, indirectPerWeek: group.indirectSets / weeks,
                perWeek: ProgressText.perWeek(group.totalPerWeek(weeks: Self.weeks)),
                exercises: group.exercises.map { GroupDetail(name: $0.name, value: ProgressText.setsAndSessions(sets: $0.sets, sessions: $0.sessions)) },
                indirect: group.indirect.map { GroupDetail(name: $0.name, value: ProgressText.indirectSets($0.sets)) },
                isOpen: openGroups.contains(name)
            )
        }
    }

    /// La franja de referencia, en series por semana.
    public var referenceBand: ClosedRange<Int> { GroupSets.weeklyReferenceRange }

    /// Escala absoluta compartida por todas las barras, en series por semana (si cada barra se
    /// escalara a su manera, la franja caería en un sitio distinto en cada una y no significaría nada).
    public var scale: Double {
        GroupSets.scale(largestPerWeek: groups.map { $0.directPerWeek + $0.indirectPerWeek }.max() ?? 0, reference: referenceBand)
    }

    public func toggleGroup(_ name: String) {
        openGroups.toggle(name)
    }
}

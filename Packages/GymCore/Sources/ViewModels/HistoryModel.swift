import Application
import Domain
import Observation
import Presentation

/// La pestaña Historial (`views/historial.js` de la PWA): la lista de sesiones, de la más reciente
/// a la más antigua, y el detalle de una, donde se puede corregir cada ejercicio. Los cambios de
/// una tarjeta se hacen sobre una copia y solo cuentan al pulsar "Guardar"; cerrar la tarjeta o
/// volver a la lista los descarta.
@MainActor
@Observable
public final class HistoryModel {
    public struct Row: Hashable, Sendable, Identifiable {
        public var id: LocalDate { date }
        public let date: LocalDate
        public let routine: String
        public let day: String
        public let month: String
        /// "Hace 3 días".
        public let relative: String
        public let summary: String
        /// Sin terminar: se pinta con tinte azul y el icono de pausa.
        public let isIncomplete: Bool
    }

    public struct DeletePrompt: Hashable, Sendable {
        public let date: LocalDate
        public let title: String
        public let message: String
    }

    /// La sesión abierta en detalle; `nil` = la lista.
    public private(set) var selectedDate: LocalDate?
    public private(set) var openCards: Set<Int> = []
    /// Copias en edición de las tarjetas abiertas, por posición.
    private var drafts: [Int: ExerciseLog] = [:]
    public private(set) var dirtyCards: Set<Int> = []
    public private(set) var focusedSeries: (log: Int, series: Int)?
    public private(set) var deletePrompt: DeletePrompt?

    private let app: AppModel
    private let navigation: NavigationModel
    private let clock: any Clock

    public init(app: AppModel, navigation: NavigationModel, clock: any Clock) {
        self.app = app
        self.navigation = navigation
        self.clock = clock
    }

    private var data: TrainingData { app.data ?? TrainingData() }

    // MARK: - Lista

    public var rows: [Row] {
        let today = clock.today()
        return data.history.sortedNewestFirst().map { session in
            let block = DateText.block(session.date)
            return Row(date: session.date, routine: routineName(session.routineID), day: block.day, month: block.month,
                       relative: DateText.relative(session.date, today: today),
                       summary: HistoryText.sessionSummary(session.logs.map { data.catalog.name(of: $0.exerciseID) }),
                       isIncomplete: !session.completed)
        }
    }

    public func open(_ date: LocalDate) {
        resetDetail()
        selectedDate = date
    }

    /// "← Volver": a la lista, sin guardar lo que no se guardó.
    public func back() {
        resetDetail()
        selectedDate = nil
    }

    /// Al volver a la pestaña: la lista (`renderHistorial`).
    public func appear() {
        back()
    }

    private func resetDetail() {
        openCards = []
        drafts = [:]
        dirtyCards = []
        focusedSeries = nil
    }

    // MARK: - Borrar

    public func requestDelete(_ date: LocalDate) {
        deletePrompt = DeletePrompt(date: date, title: HistoryText.deleteTitle, message: HistoryText.deleteMessage(date))
    }

    public func confirmDelete() async {
        guard let prompt = deletePrompt else { return }
        deletePrompt = nil
        var data = data
        data.history.removeAll { $0.date == prompt.date }
        if selectedDate == prompt.date { back() }
        await app.update(data)
        app.notice = HistoryText.deleted
    }

    public func cancelDelete() {
        deletePrompt = nil
    }

    // MARK: - Detalle

    private var session: Session? {
        selectedDate.flatMap { data.history.session(on: $0) }
    }

    public var detailTitle: String {
        guard let session else { return HistoryText.title }
        return HistoryText.detailTitle(routine: routineName(session.routineID), date: session.date)
    }

    public var isIncomplete: Bool { session.map { !$0.completed } ?? false }

    public var cards: [ExerciseCard] {
        guard let session else { return [] }
        return session.logs.enumerated().map { index, stored in
            let log = drafts[index] ?? stored
            let isDirty = dirtyCards.contains(index)
            return ExerciseCard(
                log: log, data: data, isOpen: openCards.contains(index), isEditable: true, anchor: session.date,
                focusedSeries: focusedSeries?.log == index ? focusedSeries?.series : nil,
                errors: isDirty ? log.validationErrors : [], showsRecords: false, isDirty: isDirty
            )
        }
    }

    /// Abrir una tarjeta crea su copia, con las series vacías rellenadas con el objetivo; cerrarla
    /// sin guardar la descarta.
    public func toggleCard(_ index: Int) {
        guard let session, session.logs.indices.contains(index) else { return }
        if openCards.contains(index) {
            openCards.remove(index)
            drafts[index] = nil
            dirtyCards.remove(index)
            focusedSeries = nil
        } else {
            var log = session.logs[index]
            log.actualReps = (0..<max(0, log.series)).map { series in
                (series < log.actualReps.count ? log.actualReps[series] : nil) ?? log.targetReps
            }
            drafts[index] = log
            openCards.insert(index)
        }
    }

    public func adjust(_ parameter: LogParameter, direction: Int, at index: Int) {
        edit(index) { log in
            let delta = parameter == .weight ? Double(direction) * ExerciseLog.weightStep(for: log.weight) : Double(direction)
            log.adjust(parameter, by: delta)
        }
    }

    public func set(_ parameter: LogParameter, text: String, at index: Int) {
        edit(index) { $0.set(parameter, text: text) }
    }

    public func focusSeries(_ series: Int, at index: Int) {
        if let focused = focusedSeries, focused.log == index, focused.series == series {
            focusedSeries = nil
        } else {
            focusedSeries = (index, series)
        }
    }

    public func chooseRep(_ value: Int, series: Int, at index: Int) {
        edit(index) { $0.setRep(at: series, to: value) }
    }

    private func edit(_ index: Int, _ change: (inout ExerciseLog) -> Void) {
        guard var log = drafts[index] else { return }
        change(&log)
        drafts[index] = log
        dirtyCards.insert(index)
    }

    /// "Guardar": si hay errores se marcan y no se guarda.
    public func save(_ index: Int) async {
        guard let date = selectedDate, let log = drafts[index] else { return }
        guard log.validationErrors.isEmpty else {
            app.notice = HistoryText.fixBeforeSaving
            return
        }
        var data = data
        guard let position = data.history.firstIndex(where: { $0.date == date }), data.history[position].logs.indices.contains(index) else { return }
        data.history[position].logs[index] = log
        drafts[index] = nil
        dirtyCards.remove(index)
        openCards.remove(index)
        focusedSeries = nil
        await app.update(data)
    }

    /// "Completar entreno" de una sesión sin terminar: se da por terminada y se va a Rutinas.
    public func completeWorkout() async {
        guard let date = selectedDate else { return }
        var data = data
        guard let position = data.history.firstIndex(where: { $0.date == date }) else { return }
        data.history[position].completed = true
        back()
        await app.update(data)
        navigation.showRoutines()
    }

    private func routineName(_ id: RoutineID) -> String {
        data.routines.first { $0.id == id }?.name ?? id.rawValue
    }
}

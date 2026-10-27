import Application
import Domain
import Observation
import Presentation

/// La pestaña Historial (`views/historial.js` de la PWA): la lista de sesiones, de la más reciente
/// a la más antigua, y el detalle de una. El detalle es de solo lectura y se corrige con «Editar»,
/// como en Contactos (2026-10-27; la PWA tenía un «Guardar» por tarjeta, y cerrarla o volver tiraba
/// lo corregido sin avisar): los cambios van sobre una copia de la sesión, «OK» la guarda entera y
/// «Cancelar» con cambios pregunta antes de tirarlos.
@MainActor
@Observable
public final class HistoryModel {
    public struct Row: Hashable, Sendable, Identifiable {
        public var id: LocalDate { date }
        public let date: LocalDate
        public let routine: String
        public let day: String
        public let month: String
        /// "Hace 3 días"; más de un mes, nada.
        public let relative: String?
        public let summary: String
        /// Sin terminar: se pinta con tinte azul y el icono de pausa.
        public let isIncomplete: Bool
        public let tint: RoutineTint?
    }

    /// «Cancelar» con cambios, o tocar otra vez la pestaña: «Descartar cambios» o «Seguir editando».
    public struct DiscardPrompt: Hashable, Sendable {
        /// Viene de tocar la pestaña: al descartar, a la lista.
        public let leavesDetail: Bool
    }

    /// Un mes del Historial: «Octubre de 2026» y sus sesiones.
    public struct MonthSection: Hashable, Sendable, Identifiable {
        public var id: String { title }
        public let title: String
        public let rows: [Row]
    }

    public struct DeletePrompt: Hashable, Sendable {
        public let date: LocalDate
        public let title: String
        public let message: String
    }

    /// La sesión abierta en detalle; `nil` = la lista.
    public private(set) var selectedDate: LocalDate?
    public private(set) var openCards: Set<Int> = []
    /// La copia de los ejercicios de la sesión mientras se edita; `nil` = solo lectura.
    private var drafts: [ExerciseLog]?
    /// La sesión tal como estaba al tocar «Editar»: con qué se comparan los cambios, y si al
    /// pulsar «OK» ya no es así, la sesión cambió por otro lado y no se pisa.
    private var editBase: [ExerciseLog]?
    /// Los errores que marcó el último «OK», por posición.
    private var validationErrors: [Int: [LogValidationError]] = [:]
    public private(set) var discardPrompt: DiscardPrompt?
    public private(set) var focusedSeries: (log: Int, series: Int)?
    public private(set) var deletePrompt: DeletePrompt?
    /// Lo tecleado en un campo de la sesión abierta que aún no se ha aplicado (`TypedValue`).
    public private(set) var typed: TypedValue?

    private let app: AppModel
    private let clock: any Clock

    public init(app: AppModel, clock: any Clock) {
        self.app = app
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
                       isIncomplete: !session.completed,
                       tint: RoutineTint.of(session.routineID, in: data.routines.map(\.id)))
        }
    }

    /// Las sesiones por mes, de la más reciente a la más antigua (como Fotos o Fitness).
    public var sections: [MonthSection] {
        var sections: [MonthSection] = []
        for row in rows {
            let title = DateText.monthYear(row.date)
            if let last = sections.last, last.title == title {
                sections[sections.count - 1] = MonthSection(title: title, rows: last.rows + [row])
            } else {
                sections.append(MonthSection(title: title, rows: [row]))
            }
        }
        return sections
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

    /// Tocar otra vez la pestaña: la lista (`renderHistorial`). Con cambios sin guardar, antes
    /// pregunta.
    public func reselect() {
        commitTyping()
        guard hasChanges else { return back() }
        discardPrompt = DiscardPrompt(leavesDetail: true)
    }

    private func resetDetail() {
        openCards = []
        endEditing()
    }

    private func endEditing() {
        typed = nil
        drafts = nil
        editBase = nil
        validationErrors = [:]
        focusedSeries = nil
        discardPrompt = nil
    }

    // MARK: - Borrar

    public func requestDelete(_ date: LocalDate) {
        deletePrompt = DeletePrompt(date: date, title: HistoryText.deleteTitle, message: HistoryText.deleteMessage(date))
    }

    /// Recibe el aviso que se confirma, no lo lee de `deletePrompt`: SwiftUI cierra el diálogo
    /// (`cancelDelete`) antes de ejecutar la acción del botón.
    public func confirmDelete(_ prompt: DeletePrompt) async {
        deletePrompt = nil
        var data = data
        data.history.removeAll { $0.date == prompt.date }
        if selectedDate == prompt.date { back() }
        await app.update(data)
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
        return routineName(session.routineID)
    }

    /// La fecha de la sesión, debajo del título.
    public var detailSubtitle: String {
        session.map { HistoryText.detailSubtitle($0.date) } ?? ""
    }

    public var isIncomplete: Bool { session.map { !$0.completed } ?? false }

    public var cards: [ExerciseCard] {
        guard let session else { return [] }
        return session.logs.enumerated().map { index, stored in
            let log = drafts.flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? stored
            return ExerciseCard(
                log: log, data: data, isOpen: openCards.contains(index), isEditable: isEditing, anchor: session.date,
                focusedSeries: focusedSeries?.log == index ? focusedSeries?.series : nil,
                errors: validationErrors[index] ?? [], showsRecords: false, isDirty: isChanged(index)
            )
        }
    }

    /// Abrir o cerrar una tarjeta solo cambia lo que se ve: no guarda ni descarta nada.
    public func toggleCard(_ index: Int) {
        guard let session, session.logs.indices.contains(index) else { return }
        if openCards.contains(index) {
            openCards.remove(index)
            if focusedSeries?.log == index { focusedSeries = nil }
        } else {
            openCards.insert(index)
        }
    }

    // MARK: - Editar

    public var isEditing: Bool { drafts != nil }

    /// Algo cambiado respecto a lo que había al tocar «Editar» (lo tecleado sin aplicar cuenta al
    /// salir del campo).
    public var hasChanges: Bool { !changedIndices.isEmpty }

    private var changedIndices: [Int] {
        guard let drafts, let editBase else { return [] }
        return drafts.indices.filter { isChanged($0, drafts: drafts, stored: editBase) }
    }

    private func isChanged(_ index: Int) -> Bool {
        guard let drafts, let editBase else { return false }
        return isChanged(index, drafts: drafts, stored: editBase)
    }

    /// Rellenar las series vacías al editar no cuenta como cambio.
    private func isChanged(_ index: Int, drafts: [ExerciseLog], stored: [ExerciseLog]) -> Bool {
        guard drafts.indices.contains(index), stored.indices.contains(index) else { return false }
        return drafts[index] != Self.prefilled(stored[index])
    }

    /// «Editar»: una copia de la sesión, con las series vacías rellenadas con el objetivo.
    public func startEditing() {
        guard let session else { return }
        editBase = session.logs
        drafts = session.logs.map(Self.prefilled)
        validationErrors = [:]
        focusedSeries = nil
    }

    /// «Cancelar»: sin cambios sale al momento; con cambios, pregunta.
    public func cancelEditing() {
        commitTyping()
        guard hasChanges else { return endEditing() }
        discardPrompt = DiscardPrompt(leavesDetail: false)
    }

    public var isDiscardPromptPresented: Bool { discardPrompt != nil }

    /// «Descartar cambios»: vuelve a lo guardado (y a la lista, si venía de tocar la pestaña).
    /// Recibe el aviso que se confirma, no lo lee de `discardPrompt`: SwiftUI cierra el diálogo
    /// (`keepEditing`) antes de ejecutar la acción del botón.
    public func discardChanges(_ prompt: DiscardPrompt) {
        if prompt.leavesDetail { back() } else { endEditing() }
    }

    /// «Seguir editando», o el diálogo que se cierra.
    public func keepEditing() {
        discardPrompt = nil
    }

    /// «OK»: si algo no vale, se marca, se abre la primera tarjeta con errores y no se guarda; si
    /// vale, se guardan de una vez las tarjetas cambiadas, y solo esas (las demás conservan sus
    /// series vacías). Sin cambios, no se escribe nada. Si la sesión cambió por otro lado mientras
    /// se editaba, no se pisa: se dice y se sale de editar.
    public func finishEditing() async {
        commitTyping()
        guard let drafts, let editBase, let date = selectedDate else { return }
        guard session?.logs == editBase else {
            endEditing()
            app.notice = HistoryText.changedWhileEditing
            return
        }
        let errors = Dictionary(uniqueKeysWithValues: drafts.enumerated().compactMap { index, log in
            log.validationErrors.isEmpty ? nil : (index, log.validationErrors)
        })
        guard errors.isEmpty else {
            validationErrors = errors
            if let first = errors.keys.min() { openCards.insert(first) }
            app.notice = ValidationText.reviewMarked
            return
        }
        let changed = changedIndices
        endEditing()
        guard !changed.isEmpty else { return }
        var data = data
        guard let position = data.history.firstIndex(where: { $0.date == date }) else { return }
        for index in changed { data.history[position].logs[index] = drafts[index] }
        await app.update(data)
    }

    private static func prefilled(_ stored: ExerciseLog) -> ExerciseLog {
        var log = stored
        log.actualReps = (0..<max(0, log.series)).map { series in
            (series < log.actualReps.count ? log.actualReps[series] : nil) ?? log.targetReps
        }
        return log
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

    /// Lo que se va tecleando en un campo: se aplica al salir de él o antes de la siguiente acción.
    public func type(_ parameter: LogParameter, text: String, at index: Int) {
        guard isEditing else { return }
        typed = TypedValue(parameter: parameter, text: text, index: index)
    }

    /// Aplica lo tecleado pendiente, si lo hay.
    public func commitTyping() {
        guard let typed else { return }
        self.typed = nil
        set(typed.parameter, text: typed.text, at: typed.index)
    }

    public func focusSeries(_ series: Int, at index: Int) {
        guard isEditing else { return }
        if let focused = focusedSeries, focused.log == index, focused.series == series {
            focusedSeries = nil
        } else {
            focusedSeries = (index, series)
        }
    }

    public func chooseRep(_ value: Int, series: Int, at index: Int) {
        edit(index) { $0.setRep(at: series, to: value) }
    }

    /// En solo lectura no hace nada.
    private func edit(_ index: Int, _ change: (inout ExerciseLog) -> Void) {
        commitTyping()
        guard var drafts, drafts.indices.contains(index) else { return }
        change(&drafts[index])
        self.drafts = drafts
        validationErrors[index] = nil
    }

    /// "Completar entreno" de una sesión sin terminar: se da por terminada y el detalle se queda,
    /// ya sin la etiqueta ni el botón (2026-10-27; la PWA saltaba a Hoy, y en iOS una acción no
    /// cambia de pestaña sola).
    public func completeWorkout() async {
        guard let date = selectedDate else { return }
        var data = data
        guard let position = data.history.firstIndex(where: { $0.date == date }) else { return }
        data.history[position].completed = true
        await app.update(data)
    }

    private func routineName(_ id: RoutineID) -> String {
        data.routines.first { $0.id == id }?.name ?? id.rawValue
    }
}

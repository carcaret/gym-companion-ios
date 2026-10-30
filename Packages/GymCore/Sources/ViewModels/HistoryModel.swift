import Application
import Domain
import Observation
import Presentation

/// La pestaña Historial (`views/historial.js` de la PWA): la lista de sesiones, de la más reciente
/// a la más antigua, y el detalle de una. El detalle es de solo lectura y se corrige con «Editar»,
/// en una hoja, como un contacto o un evento del Calendario (2026-10-27; la PWA tenía un «Guardar»
/// por tarjeta, y cerrarla o volver tiraba lo corregido sin avisar): los cambios van sobre una copia
/// de la sesión, la ✓ guarda lo cambiado y la ✕ con cambios pregunta antes de tirarlos. La edición
/// va en `HistoryModel+Editing`; el estado es `internal` para que lo vea.
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
        /// El reloj guardó en Salud un entreno de ese día: se borra también.
        public let deletesFromFitness: Bool
    }

    /// La sesión abierta en detalle; `nil` = la lista.
    public private(set) var selectedDate: LocalDate?
    var openCards: Set<Int> = []
    /// La copia de los ejercicios de la sesión mientras se edita; `nil` = solo lectura.
    var drafts: [ExerciseLog]?
    /// La sesión tal como estaba al tocar «Editar»: con qué se comparan los cambios, y si al
    /// pulsar la ✓ ya no es así, la sesión cambió por otro lado y no se pisa.
    var editBase: [ExerciseLog]?
    var editing = LogEditing()
    /// La ✕ con cambios: «Descartar cambios» o «Seguir editando».
    public var isDiscardPromptPresented = false
    public private(set) var deletePrompt: DeletePrompt?

    let app: AppModel
    private let clock: any Clock
    /// Los entrenos de Gym en Salud; `nil` en la demo, que no toca Salud.
    private let healthWorkouts: (any HealthWorkoutStore)?

    public init(app: AppModel, clock: any Clock, healthWorkouts: (any HealthWorkoutStore)? = nil) {
        self.app = app
        self.clock = clock
        self.healthWorkouts = healthWorkouts
    }

    var data: TrainingData { app.current }

    // MARK: - Lista

    public var rows: [Row] {
        let today = clock.today()
        return data.history.sortedNewestFirst().map { session in
            let block = DateText.block(session.date)
            return Row(date: session.date, routine: data.routines.name(of: session.routineID), day: block.day, month: block.month,
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

    /// Volver a la lista (la flecha de iOS o deslizar).
    public func back() {
        resetDetail()
        selectedDate = nil
    }

    /// Tocar otra vez la pestaña: la lista (`renderHistorial`). Mientras se edita no se puede: la
    /// hoja de editar tapa las pestañas.
    public func reselect() {
        back()
    }

    private func resetDetail() {
        openCards = []
        endEditing()
    }

    // MARK: - Borrar

    /// Antes de preguntar, mira si hay un entreno de Gym en Salud ese día, para decirlo.
    public func requestDelete(_ date: LocalDate) async {
        let fromFitness = await healthWorkouts?.hasWorkouts(on: date) ?? false
        deletePrompt = DeletePrompt(date: date, title: HistoryText.deleteTitle,
                                    message: HistoryText.deleteMessage(date, fromFitness: fromFitness), deletesFromFitness: fromFitness)
    }

    /// Recibe el aviso que se confirma, no lo lee de `deletePrompt`: SwiftUI cierra el diálogo
    /// (`cancelDelete`) antes de ejecutar la acción del botón.
    public func confirmDelete(_ prompt: DeletePrompt) async {
        deletePrompt = nil
        var data = data
        data.history.removeAll { $0.date == prompt.date }
        if selectedDate == prompt.date { back() }
        await app.update(data)
        guard prompt.deletesFromFitness, let healthWorkouts else { return }
        do {
            try await healthWorkouts.deleteWorkouts(on: prompt.date)
        } catch {
            app.notice = HistoryText.fitnessDeleteFailed
        }
    }

    public func cancelDelete() {
        deletePrompt = nil
    }

    // MARK: - Detalle

    var session: Session? {
        selectedDate.flatMap { data.history.session(on: $0) }
    }

    public var detailTitle: String {
        guard let session else { return HistoryText.title }
        return data.routines.name(of: session.routineID)
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
                focusedSeries: editing.focusedSeries(at: index),
                errors: editing.validationErrors[index] ?? [], showsRecords: false, isDirty: isChanged(index)
            )
        }
    }

    /// Abrir o cerrar una tarjeta solo cambia lo que se ve: no guarda ni descarta nada.
    public func toggleCard(_ index: Int) {
        guard let session, session.logs.indices.contains(index) else { return }
        if openCards.contains(index) { editing.unfocus(at: index) }
        openCards.toggle(index)
    }

    /// "Completar entreno" de una sesión sin terminar: se da por terminada y el detalle se queda,
    /// ya sin la etiqueta ni el botón (2026-10-27; la PWA saltaba a Hoy, y en iOS una acción no
    /// cambia de pestaña sola).
    public func completeWorkout() async {
        guard let date = selectedDate else { return }
        guard var session = data.history.session(on: date) else { return }
        session.completed = true
        var data = data
        data.history.replace(session)
        await app.update(data)
    }
}

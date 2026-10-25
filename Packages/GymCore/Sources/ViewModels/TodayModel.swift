import Application
import Domain
import Observation
import Presentation

/// La pantalla Hoy (pestaña Rutinas, `views/hoy.js` de la PWA): elegir rutina, verla, entrenar y
/// ver el entreno terminado. Todo lo que pinta la vista sale de aquí ya calculado; las reglas son
/// del dominio y los textos, de `TodayText`.
@MainActor
@Observable
public final class TodayModel {
    public enum Stage: Hashable, Sendable {
        case selector
        case preview(RoutineID)
        case active
        case completed
    }

    public struct RoutineRow: Hashable, Sendable {
        public let id: RoutineID
        public let title: String
        public let subtitle: String
        /// "Próxima vez: B en vez de A", si hay un cambio recíproco pendiente esta semana.
        public let pendingNote: String?
    }

    public enum SeriesState: Hashable, Sendable {
        /// Llegó al objetivo.
        case done
        /// Rellenada por debajo del objetivo.
        case filled
        case empty
    }

    public struct SeriesCell: Hashable, Sendable {
        public let label: String
        public let text: String
        public let value: Int?
        public let state: SeriesState
        public let isFocused: Bool
        public let hasError: Bool
    }

    public enum ChipRelation: Hashable, Sendable { case below, atTarget, above }

    public struct Chip: Hashable, Sendable {
        public let value: Int
        public let isCurrent: Bool
        public let relation: ChipRelation
    }

    /// Una tarjeta de ejercicio (en la vista previa, solo lectura; en el entreno, editable).
    public struct Card: Hashable, Sendable, Identifiable {
        public var id: ExerciseID { exerciseID }
        public let exerciseID: ExerciseID
        public let title: String
        public let subtitle: String
        public let isOpen: Bool
        /// En la vista previa todo es de solo lectura: sin −/+, sin campos y sin botones abajo.
        public let isEditable: Bool
        public let weight: Double
        public let series: Int
        public let targetReps: Int
        public let cells: [SeriesCell]
        /// Los chips de la serie enfocada (solo en el entreno).
        public let chips: [Chip]
        public let strip: HistoryStripContent?
        public let isVolumeRecord: Bool
        public let isE1RMRecord: Bool
        public let isSkipped: Bool
        public let isOneOff: Bool
        public let skipLabel: String
        public let removeLabel: String
        /// Errores de la última vez que se intentó terminar.
        public let errors: [LogValidationError]

        public var hasRecord: Bool { isVolumeRecord || isE1RMRecord }
    }

    /// Una línea del entreno terminado (el formato del historial).
    public struct SummaryRow: Hashable, Sendable {
        public let title: String
        public let subtitle: String
        /// Saltado: se pinta con el fondo de saltado y sin botones.
        public let isSkipped: Bool
    }

    public enum PickerPurpose: Hashable, Sendable {
        case add
        case swap(index: Int)
    }

    /// El selector de ejercicios (añadir o cambiar).
    public struct Picker: Hashable, Sendable {
        public let purpose: PickerPurpose
        public let title: String
        /// Ya ordenados y filtrados por la búsqueda.
        public let exercises: [Exercise]
        /// El chip "Solo esta sesión" (solo al añadir con entreno en curso).
        public let offersOneOff: Bool
        public let isOneOff: Bool
        /// "Crear nuevo ejercicio" (al añadir, y no si es puntual: lo nuevo entra en la rutina).
        public let canCreate: Bool
    }

    public struct RemovalPrompt: Hashable, Sendable {
        public let exerciseID: ExerciseID
        public let title: String
        public let message: String
    }

    public struct ReciprocalOffer: Hashable, Sendable {
        public let routine: RoutineID
        public let swap: PendingSwap
        public let title: String
        public let message: String
    }

    // MARK: - Estado

    private var storedStage: Stage = .selector
    /// Tarjetas abiertas de la vista previa (independientes entre sí), por posición.
    public private(set) var openPreviewCards: Set<Int> = []
    /// La tarjeta abierta del entreno (como mucho una), por ejercicio: sigue abierta aunque cambie
    /// de posición.
    public private(set) var openExercise: ExerciseID?
    /// La serie enfocada, que enseña los chips.
    public private(set) var focusedSeries: (log: Int, series: Int)?
    public private(set) var validationErrors: [Int: [LogValidationError]] = [:]
    public private(set) var pickerPurpose: PickerPurpose?
    public var pickerQuery = ""
    public private(set) var pickerOneOff = false
    public var isCreatePresented = false
    public var createName = ""
    public private(set) var removalPrompt: RemovalPrompt?
    public private(set) var reciprocalOffer: ReciprocalOffer?

    private let app: AppModel
    private let sync: SyncModel
    private let clock: any Clock

    public init(app: AppModel, sync: SyncModel, clock: any Clock) {
        self.app = app
        self.sync = sync
        self.clock = clock
    }

    private var data: TrainingData { app.data ?? TrainingData() }
    private var today: LocalDate { clock.today() }
    private var todaySession: Session? { data.history.session(on: today) }
    private var activeSession: Session? { todaySession.flatMap { $0.completed ? nil : $0 } }

    /// Con un entreno en curso, siempre el entreno.
    public var stage: Stage { activeSession != nil ? .active : storedStage }

    public var title: String {
        switch stage {
        case .selector: TodayText.selectorTitle
        case .preview(let routine): TodayText.previewTitle(name(of: routine))
        case .active: TodayText.activeTitle(name(of: activeSession?.routineID))
        case .completed: name(of: todaySession?.routineID)
        }
    }

    /// "Entreno en curso — Full Body - Día 1".
    public var activeStatus: String { TodayText.activeStatus(name(of: activeSession?.routineID)) }

    // MARK: - Selector

    public var routineRows: [RoutineRow] {
        data.routines.map { routine in
            let names = routine.exerciseIDs.map { data.catalog.name(of: $0) }
            var note: String?
            if let pending = data.pendingSwaps[routine.id], pending.weekStart == today.weekStart {
                note = TodayText.pendingSwapNote(to: data.catalog.name(of: pending.to), from: data.catalog.name(of: pending.from))
            }
            return RoutineRow(id: routine.id, title: routine.name, subtitle: TodayText.routineSummary(names), pendingNote: note)
        }
    }

    /// Al volver a la pestaña: el selector, salvo con un entreno en curso (`renderHoy`).
    public func appear() {
        storedStage = .selector
        openPreviewCards = []
        if activeSession == nil { openExercise = nil }
    }

    public func select(_ routine: RoutineID) {
        storedStage = .preview(routine)
        openPreviewCards = []
    }

    public func backToSelector() {
        storedStage = .selector
        openPreviewCards = []
        openExercise = nil
    }

    // MARK: - Vista previa

    /// Cada ejercicio con los valores con los que arrancaría (`getBestRecentValuesForExercise`).
    public var previewCards: [Card] {
        guard case .preview(let routine) = stage else { return [] }
        let exerciseIDs = data.routines.first { $0.id == routine }?.exerciseIDs ?? []
        return exerciseIDs.enumerated().map { index, id in
            let seed = data.history.bestRecentSeed(for: id, today: today)
            let log = ExerciseLog(exerciseID: id, series: seed.series, targetReps: seed.targetReps, actualReps: seed.actualReps, weight: seed.weight)
            return card(for: log, index: index, isOpen: openPreviewCards.contains(index), editable: false, anchor: today)
        }
    }

    public func togglePreviewCard(_ index: Int) {
        if openPreviewCards.contains(index) { openPreviewCards.remove(index) } else { openPreviewCards.insert(index) }
    }

    public func start() async {
        guard case .preview(let routine) = storedStage else { return }
        let weekStart = today.weekStart
        let today = today
        var data = data
        let routineIDs = data.routines.first { $0.id == routine }?.exerciseIDs ?? []
        let consumption = PendingSwap.consume(data.pendingSwaps[routine], in: routineIDs, weekStart: weekStart)
        if consumption.clearNow { data.pendingSwaps[routine] = nil }
        let history = data.history
        let session = Session.planned(date: today, routine: routine, exerciseIDs: consumption.exerciseIDs) { id, _ in
            history.bestRecentSeed(for: id, today: today)
        }
        data.history.removeAll { $0.date == today }
        data.history.append(session)
        openExercise = nil
        focusedSeries = nil
        validationErrors = [:]
        await app.update(data)
        app.notice = TodayText.started
    }

    // MARK: - Entreno en curso

    public var activeCards: [Card] {
        guard let session = activeSession else { return [] }
        return session.logs.enumerated().map { index, log in
            card(for: log, index: index, isOpen: log.exerciseID == openExercise, editable: true, anchor: session.date)
        }
    }

    /// Las tarjetas se pueden arrastrar solo con un entreno en curso (no en la vista previa).
    public var canReorder: Bool { stage == .active }

    /// La insignia de récord del título.
    public var hasRecord: Bool { activeCards.contains(where: \.hasRecord) }

    /// Acordeón: abrir una cierra las demás; tocar la abierta la cierra.
    public func toggleCard(_ exercise: ExerciseID) {
        openExercise = openExercise == exercise ? nil : exercise
    }

    /// Botones −/+ (`direction` = −1 o 1). En el peso, el escalón depende de la carga.
    public func adjust(_ parameter: LogParameter, direction: Int, at index: Int) async {
        await editLog(at: index) { log in
            let delta = parameter == .weight ? Double(direction) * ExerciseLog.weightStep(for: log.weight) : Double(direction)
            log.adjust(parameter, by: delta)
        }
    }

    /// Valor tecleado en peso, series u objetivo.
    public func set(_ parameter: LogParameter, text: String, at index: Int) async {
        await editLog(at: index) { $0.set(parameter, text: text) }
    }

    /// Tocar una serie enseña sus chips; tocarla otra vez los esconde.
    public func focusSeries(_ series: Int, at index: Int) {
        if let focused = focusedSeries, focused.log == index, focused.series == series {
            focusedSeries = nil
        } else {
            focusedSeries = (index, series)
        }
    }

    /// Un chip de reps de la serie enfocada.
    public func chooseRep(_ value: Int, series: Int, at index: Int) async {
        await editLog(at: index) { $0.setRep(at: series, to: value) }
    }

    public func toggleSkip(at index: Int) async {
        await editLog(at: index) { $0.toggleSkip() }
    }

    /// Arrastrar una tarjeta. Con entreno en curso los logs mandan y la rutina se deriva de ellos:
    /// sin los puntuales y con cada cambio guardado por su ejercicio original.
    public func reorder(from source: Int, to destination: Int) async {
        guard var session = activeSession, source != destination, session.logs.indices.contains(source),
              session.logs.indices.contains(destination) else { return }
        var data = data
        session.logs = session.logs.moving(from: source, to: destination)
        if let routine = data.routines.firstIndex(where: { $0.id == session.routineID }) {
            data.routines[routine].exerciseIDs = session.logs.filter { !$0.oneOff }.map { $0.swappedFrom ?? $0.exerciseID }
        }
        replaceSession(session, in: &data)
        focusedSeries = nil
        await app.update(data)
        app.notice = TodayText.reordered
    }

    /// Terminar: si falta algo, se marca y se abre la primera tarjeta con errores; si no, se
    /// termina, se borra el pendiente de la rutina y se sube ya.
    public func finish() async {
        guard var session = activeSession else { return }
        focusedSeries = nil
        let validation = session.validation
        guard validation.isValid else {
            validationErrors = validation.errorsByLog
            if let first = validation.errorsByLog.keys.min() { openExercise = session.logs[first].exerciseID }
            app.notice = TodayText.incomplete
            return
        }
        validationErrors = [:]
        session.finish()
        var data = data
        data.pendingSwaps[session.routineID] = nil
        replaceSession(session, in: &data)
        storedStage = .completed
        openExercise = nil
        app.notice = TodayText.finished
        let result = await app.finishWorkout(data)
        sync.workoutFinished(result)
    }

    // MARK: - Entreno terminado

    public var completedRows: [SummaryRow] {
        guard stage == .completed, let session = todaySession else { return [] }
        return session.logs.map { SummaryRow(title: data.catalog.name(of: $0.exerciseID), subtitle: LogText.summary($0), isSkipped: $0.skipped) }
    }

    /// "← Volver a rutinas".
    public func backFromCompleted() {
        backToSelector()
    }

    // MARK: - Añadir y cambiar ejercicios

    public var picker: Picker? {
        guard let purpose = pickerPurpose, let session = activeSession else { return nil }
        let present = Set(session.logs.map(\.exerciseID))
        let needle = pickerQuery.trimmingWhitespace().searchFolded
        func matching(_ exercises: [Exercise]) -> [Exercise] {
            needle.isEmpty ? exercises : exercises.filter { $0.name.searchFolded.contains(needle) }
        }
        switch purpose {
        case .add:
            let routine = Set(data.routines.first { $0.id == session.routineID }?.exerciseIDs ?? [])
            let candidates = data.catalog.all.filter { !routine.contains($0.id) && !present.contains($0.id) }
                .sorted { SpanishCollation.precedes($0.name, $1.name) }
            return Picker(purpose: purpose, title: TodayText.addTitle(name(of: session.routineID)), exercises: matching(candidates),
                          offersOneOff: true, isOneOff: pickerOneOff, canCreate: !pickerOneOff)
        case .swap(let index):
            let candidates = data.catalog.all.filter { !present.contains($0.id) }
            let sorted = data.catalog.sortedForSwap(candidates, replacing: session.logs[index].exerciseID, routines: data.routines,
                                                    currentRoutine: session.routineID)
            return Picker(purpose: purpose, title: TodayText.swapTitle, exercises: matching(sorted), offersOneOff: false, isOneOff: false, canCreate: false)
        }
    }

    /// "+ Ejercicio".
    public func openAddPicker() {
        guard activeSession != nil else { return }
        openPicker(.add)
    }

    /// "Cambiar por otro".
    public func openSwapPicker(at index: Int) {
        guard let session = activeSession, session.logs.indices.contains(index) else { return }
        guard session.logs.count < data.catalog.ids.count else {
            app.notice = TodayText.noMoreExercises
            return
        }
        openPicker(.swap(index: index))
    }

    private func openPicker(_ purpose: PickerPurpose) {
        pickerPurpose = purpose
        pickerQuery = ""
        pickerOneOff = false
    }

    public func toggleOneOff() {
        pickerOneOff.toggle()
    }

    public func closePicker() {
        pickerPurpose = nil
    }

    public func choose(_ exercise: ExerciseID) async {
        guard let purpose = pickerPurpose else { return }
        pickerPurpose = nil
        switch purpose {
        case .add: await add(exercise, oneOff: pickerOneOff)
        case .swap(let index): await swap(at: index, to: exercise)
        }
    }

    private func add(_ exercise: ExerciseID, oneOff: Bool) async {
        guard let data = adding(exercise, oneOff: oneOff, to: data) else { return }
        await app.update(data)
        app.notice = TodayText.added(data.catalog.name(of: exercise), oneOff: oneOff)
    }

    /// El ejercicio entra en el entreno y, si no es puntual, al final de la rutina.
    private func adding(_ exercise: ExerciseID, oneOff: Bool, to data: TrainingData) -> TrainingData? {
        guard var session = data.history.session(on: today), !session.completed else { return nil }
        var data = data
        var log = ExerciseLog(planning: exercise, from: data.history.bestRecentSeed(for: exercise, today: today))
        log.oneOff = oneOff
        if !oneOff, let routine = data.routines.firstIndex(where: { $0.id == session.routineID }) {
            data.routines[routine].exerciseIDs.append(exercise)
        }
        session.logs.append(log)
        replaceSession(session, in: &data)
        return data
    }

    /// "Crear nuevo ejercicio": siempre entra en la rutina. Si ya existe, se avisa y sigue abierto.
    public func createExercise() async {
        let name = createName.trimmingWhitespace()
        guard !name.isEmpty else {
            isCreatePresented = false
            return
        }
        let id = ExerciseID(ExerciseID.slug(from: name))
        guard data.catalog[id] == nil else {
            app.notice = TodayText.alreadyExists
            return
        }
        isCreatePresented = false
        pickerPurpose = nil
        createName = ""
        var withExercise = data
        withExercise.catalog = Catalog(withExercise.catalog.all + [Exercise(id: id, name: name)])
        guard let updated = adding(id, oneOff: false, to: withExercise) else { return }
        await app.update(updated)
        app.notice = TodayText.created(name)
    }

    private func swap(at index: Int, to exercise: ExerciseID) async {
        guard var session = activeSession, session.logs.indices.contains(index) else { return }
        let outgoing = session.logs[index].exerciseID
        let swapped: ExerciseLog
        do {
            swapped = try session.swapExercise(at: index, to: exercise, seed: data.history.bestRecentSeed(for: exercise, today: today))
        } catch .duplicate {
            app.notice = TodayText.duplicateInWorkout
            return
        } catch {
            return
        }
        var data = data
        replaceSession(session, in: &data)
        openExercise = exercise
        focusedSeries = nil
        await app.update(data)
        app.notice = TodayText.swapped(to: data.catalog.name(of: exercise))
        if swapped.swappedFrom != nil { offerReciprocal(from: session.routineID, new: exercise, outgoing: outgoing) }
    }

    /// Si el ejercicio nuevo es de otra rutina (y solo de una) que aún no se ha hecho esta semana,
    /// se ofrece hacer el cambio inverso allí la próxima vez.
    private func offerReciprocal(from routine: RoutineID, new: ExerciseID, outgoing: ExerciseID) {
        guard let target = data.routines.reciprocalSwapTarget(from: routine, for: new) else { return }
        let weekStart = today.weekStart
        guard !data.history.hasCompletedSession(of: target, inWeekStarting: weekStart),
              let swap = PendingSwap.make(from: new, to: outgoing, targetRoutine: data.routines.first { $0.id == target }?.exerciseIDs ?? [],
                                          weekStart: weekStart)
        else { return }
        reciprocalOffer = ReciprocalOffer(
            routine: target, swap: swap, title: TodayText.reciprocalTitle,
            message: TodayText.reciprocalMessage(new: data.catalog.name(of: new), outgoing: data.catalog.name(of: outgoing), routine: name(of: target))
        )
    }

    public func acceptReciprocal() async {
        guard let offer = reciprocalOffer else { return }
        reciprocalOffer = nil
        var data = data
        data.pendingSwaps[offer.routine] = offer.swap
        await app.update(data)
        app.notice = TodayText.reciprocalScheduled(name(of: offer.routine))
    }

    public func declineReciprocal() {
        reciprocalOffer = nil
    }

    // MARK: - Quitar

    /// "Quitar" (puntual: sin preguntar) o "Quitar de rutina" (pide confirmación).
    public func requestRemoval(at index: Int) async {
        guard let session = activeSession, session.logs.indices.contains(index) else { return }
        let log = session.logs[index]
        if log.oneOff {
            await removeFromWorkout(log.exerciseID)
            app.notice = TodayText.removedOneOff
            return
        }
        removalPrompt = RemovalPrompt(exerciseID: log.exerciseID, title: TodayText.removeTitle,
                                      message: TodayText.removeMessage(exercise: data.catalog.name(of: log.exerciseID), routine: name(of: session.routineID)))
    }

    public func confirmRemoval() async {
        guard let prompt = removalPrompt, let session = activeSession else { return }
        removalPrompt = nil
        var data = data
        if let routine = data.routines.firstIndex(where: { $0.id == session.routineID }) {
            data.routines[routine].exerciseIDs.removeAll { $0 == prompt.exerciseID }
        }
        await removeFromWorkout(prompt.exerciseID, in: data)
        app.notice = TodayText.removed(from: name(of: session.routineID))
    }

    public func cancelRemoval() {
        removalPrompt = nil
    }

    private func removeFromWorkout(_ exercise: ExerciseID, in data: TrainingData? = nil) async {
        var data = data ?? self.data
        guard var session = data.history.session(on: today), !session.completed else { return }
        session.logs.removeAll { $0.exerciseID == exercise }
        replaceSession(session, in: &data)
        if openExercise == exercise { openExercise = nil }
        focusedSeries = nil
        validationErrors = [:]
        await app.update(data)
    }

    // MARK: - Ayudas

    private func editLog(at index: Int, _ change: (inout ExerciseLog) -> Void) async {
        guard var session = activeSession, session.logs.indices.contains(index) else { return }
        change(&session.logs[index])
        var data = data
        replaceSession(session, in: &data)
        await app.update(data)
    }

    private func replaceSession(_ session: Session, in data: inout TrainingData) {
        guard let position = data.history.firstIndex(where: { $0.date == session.date }) else { return }
        data.history[position] = session
    }

    private func name(of routine: RoutineID?) -> String {
        guard let routine else { return "" }
        return data.routines.first { $0.id == routine }?.name ?? routine.rawValue
    }

    private func card(for log: ExerciseLog, index: Int, isOpen: Bool, editable: Bool, anchor: LocalDate) -> Card {
        let errors = editable ? validationErrors[index] ?? [] : []
        let focused = editable && focusedSeries?.log == index ? focusedSeries?.series : nil
        let cells = (0..<max(0, log.series)).map { series in
            let value = series < log.actualReps.count ? log.actualReps[series] : nil
            let state: SeriesState = value.map { $0 >= log.targetReps ? .done : .filled } ?? .empty
            return SeriesCell(label: TodayText.seriesLabel(series), text: value.map(String.init) ?? TodayText.emptyRep, value: value, state: state,
                              isFocused: focused == series, hasError: errors.contains { $0.repIndex == series })
        }
        var chips: [Chip] = []
        if let focused, focused < log.series {
            let current = (focused < log.actualReps.count ? log.actualReps[focused] : nil) ?? log.targetReps
            chips = RepChips.values(around: current).map { value in
                Chip(value: value, isCurrent: value == current,
                     relation: value < log.targetReps ? .below : value == log.targetReps ? .atTarget : .above)
            }
        }
        let records = editable ? log.records(against: data.history.filter { $0.date != anchor }) : nil
        return Card(
            exerciseID: log.exerciseID, title: data.catalog.name(of: log.exerciseID), subtitle: LogText.summary(log), isOpen: isOpen, isEditable: editable,
            weight: log.weight, series: log.series, targetReps: log.targetReps, cells: cells, chips: chips,
            strip: HistoryStrip.make(history: data.history, exercise: log.exerciseID, current: log, anchor: anchor),
            isVolumeRecord: records?.isVolumeRecord ?? false, isE1RMRecord: records?.isE1RMRecord ?? false,
            isSkipped: log.skipped, isOneOff: log.oneOff, skipLabel: TodayText.skipLabel(skipped: log.skipped),
            removeLabel: TodayText.removeLabel(oneOff: log.oneOff), errors: errors
        )
    }
}

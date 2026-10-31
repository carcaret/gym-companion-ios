import Domain
import Presentation

/// El entreno en curso, terminarlo y quitar ejercicios.
extension TodayModel {
    // MARK: - Entreno en curso

    public var activeCards: [ExerciseCard] {
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
        await editLog(at: index) { $0.step(parameter, direction: direction) }
    }

    /// Valor tecleado en peso, series u objetivo.
    public func set(_ parameter: LogParameter, text: String, at index: Int) async {
        await editLog(at: index) { $0.set(parameter, text: text) }
    }

    /// Lo que se va tecleando en un campo: se aplica al salir de él o antes de la siguiente acción.
    public func type(_ parameter: LogParameter, text: String, at index: Int) {
        editing.type(parameter, text: text, at: index)
    }

    /// Aplica lo tecleado pendiente, si lo hay.
    public func commitTyping() async {
        guard let typed = editing.takeTyped() else { return }
        await set(typed.parameter, text: typed.text, at: typed.index)
    }

    /// Tocar una serie enseña sus chips; tocarla otra vez los esconde.
    public func focusSeries(_ series: Int, at index: Int) {
        editing.focus(series, at: index)
    }

    /// Un chip de reps de la serie enfocada.
    public func chooseRep(_ value: Int, series: Int, at index: Int) async {
        await editLog(at: index) { $0.setRep(at: series, to: value) }
    }

    public func toggleSkip(at index: Int) async {
        await editLog(at: index) { $0.toggleSkip() }
    }

    /// Arrastrar una tarjeta (la rutina sigue al entreno: `reorderWorkout`).
    public func reorder(from source: Int, to destination: Int) async {
        await commitTyping()
        var data = data
        guard data.reorderWorkout(from: source, to: destination, on: today) else { return }
        editing.unfocus()
        await app.update(data)
    }

    /// Lo que da `onMove` de SwiftUI: la posición antes de la que se suelta (una más allá de la
    /// final, si se mueve hacia abajo).
    public func moveCard(from source: Int, toOffset offset: Int) async {
        await reorder(from: source, to: offset > source ? offset - 1 : offset)
    }

    /// «Finalizar entreno»: si falta algo, se marca y se abre la primera tarjeta con errores; si no,
    /// pregunta antes de terminar (`confirmFinish`).
    public func requestFinish() async {
        await commitTyping()
        guard activeSession != nil else { return }
        editing.unfocus()
        guard validateForFinish() else { return }
        isFinishPromptPresented = true
    }

    /// «Finalizar» en el globo: se termina, se borra el pendiente de la rutina, se sube ya y se
    /// vuelve a las rutinas (sin pantalla de entreno terminado: decisión del usuario, 2026-10-31).
    /// Vuelve a validar: los datos pueden haber cambiado mientras el globo estaba abierto.
    public func confirmFinish() async {
        isFinishPromptPresented = false
        guard activeSession != nil, validateForFinish() else { return }
        var data = data
        data.finishWorkout(on: today)
        storedStage = .selector
        openExercise = nil
        // Si no se puede subir, no se interrumpe: la nube se queda pendiente y se sube sola.
        _ = await app.finishWorkout(data)
    }

    public func cancelFinish() {
        isFinishPromptPresented = false
    }

    /// Marca los errores del entreno en curso y avisa; devuelve si se puede terminar.
    private func validateForFinish() -> Bool {
        guard let session = activeSession else { return false }
        let validation = session.validation
        editing.validationErrors = validation.errorsByLog
        guard validation.isValid else {
            if let first = validation.errorsByLog.keys.min() { openExercise = session.logs[first].exerciseID }
            app.notice = ValidationText.reviewMarked
            return false
        }
        return true
    }

    // MARK: - Quitar

    /// "Quitar" (puntual: sin preguntar) o "Quitar de rutina" (pide confirmación).
    public func requestRemoval(at index: Int) async {
        await commitTyping()
        guard let session = activeSession, session.logs.indices.contains(index) else { return }
        let log = session.logs[index]
        if log.oneOff {
            await remove(log.exerciseID, alsoFromRoutine: false)
            return
        }
        removalPrompt = RemovalPrompt(exerciseID: log.exerciseID, title: TodayText.removeTitle,
                                      message: TodayText.removeMessage(exercise: data.catalog.name(of: log.exerciseID),
                                                                       routine: data.routines.name(of: session.routineID)))
    }

    /// Recibe el aviso que se confirma, no lo lee de `removalPrompt`: SwiftUI cierra el diálogo
    /// (`cancelRemoval`) antes de ejecutar la acción del botón.
    public func confirmRemoval(_ prompt: RemovalPrompt) async {
        guard activeSession != nil else { return }
        removalPrompt = nil
        await remove(prompt.exerciseID, alsoFromRoutine: true)
    }

    public func cancelRemoval() {
        removalPrompt = nil
    }

    private func remove(_ exercise: ExerciseID, alsoFromRoutine: Bool) async {
        guard activeSession != nil else { return }
        var data = data
        data.removeFromWorkout(exercise, alsoFromRoutine: alsoFromRoutine, on: today)
        if openExercise == exercise { openExercise = nil }
        editing.unfocus()
        editing.validationErrors = [:]
        await app.update(data)
    }

    // MARK: - Ayudas

    func editLog(at index: Int, _ change: (inout ExerciseLog) -> Void) async {
        await commitTyping()
        guard var session = activeSession, session.logs.indices.contains(index) else { return }
        change(&session.logs[index])
        var data = data
        data.history.replace(session)
        await app.update(data)
    }
}

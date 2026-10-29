import Domain
import Presentation

/// «Editar» en el detalle del Historial: una copia de la sesión que la ✓ guarda y la ✕ tira.
extension HistoryModel {
    public var isEditing: Bool { drafts != nil }

    /// Lo tecleado en un campo de la sesión abierta que aún no se ha aplicado (`TypedValue`).
    public var typed: TypedValue? { editing.typed }

    /// Algo cambiado respecto a lo que había al tocar «Editar» (lo tecleado sin aplicar cuenta al
    /// salir del campo).
    public var hasChanges: Bool { !changedIndices.isEmpty }

    private var changedIndices: [Int] {
        guard let drafts, let editBase else { return [] }
        return drafts.indices.filter { isChanged($0, drafts: drafts, stored: editBase) }
    }

    func isChanged(_ index: Int) -> Bool {
        guard let drafts, let editBase else { return false }
        return isChanged(index, drafts: drafts, stored: editBase)
    }

    /// Rellenar las series vacías al editar no cuenta como cambio.
    private func isChanged(_ index: Int, drafts: [ExerciseLog], stored: [ExerciseLog]) -> Bool {
        guard drafts.indices.contains(index), stored.indices.contains(index) else { return false }
        return drafts[index] != stored[index].prefilledWithTarget
    }

    /// «Editar»: una copia de la sesión, con las series vacías rellenadas con el objetivo.
    public func startEditing() {
        guard let session else { return }
        editBase = session.logs
        drafts = session.logs.map(\.prefilledWithTarget)
        editing.reset()
    }

    /// La ✕: sin cambios sale al momento; con cambios, pregunta.
    public func requestClose() {
        commitTyping()
        guard hasChanges else { return endEditing() }
        isDiscardPromptPresented = true
    }

    /// «Descartar cambios»: vuelve a lo guardado y cierra la hoja. No depende del diálogo, que
    /// SwiftUI cierra (`keepEditing`) antes de ejecutar la acción del botón.
    public func discardChanges() {
        endEditing()
    }

    /// «Seguir editando», o el diálogo que se cierra.
    public func keepEditing() {
        isDiscardPromptPresented = false
    }

    /// La ✓: si algo no vale, se marca, se abre la primera tarjeta con errores y no se guarda; si
    /// vale, se guardan de una vez las tarjetas cambiadas, y solo esas (las demás conservan sus
    /// series vacías). Sin cambios, no se escribe nada. Si la sesión cambió por otro lado mientras
    /// se editaba, no se pisa: se dice y se sale de editar. Valida como al terminar un entreno: los
    /// ejercicios saltados no se validan.
    public func finishEditing() async {
        commitTyping()
        guard let drafts, let editBase, var session else { return }
        guard session.logs == editBase else {
            endEditing()
            app.notice = HistoryText.changedWhileEditing
            return
        }
        let validation = drafts.validation
        guard validation.isValid else {
            editing.validationErrors = validation.errorsByLog
            if let first = validation.errorsByLog.keys.min() { openCards.insert(first) }
            app.notice = ValidationText.reviewMarked
            return
        }
        let changed = changedIndices
        endEditing()
        guard !changed.isEmpty else { return }
        for index in changed { session.logs[index] = drafts[index] }
        var data = data
        data.history.replace(session)
        await app.update(data)
    }

    public func adjust(_ parameter: LogParameter, direction: Int, at index: Int) {
        edit(index) { $0.step(parameter, direction: direction) }
    }

    public func set(_ parameter: LogParameter, text: String, at index: Int) {
        edit(index) { $0.set(parameter, text: text) }
    }

    /// Lo que se va tecleando en un campo: se aplica al salir de él o antes de la siguiente acción.
    public func type(_ parameter: LogParameter, text: String, at index: Int) {
        guard isEditing else { return }
        editing.type(parameter, text: text, at: index)
    }

    /// Aplica lo tecleado pendiente, si lo hay.
    public func commitTyping() {
        guard let typed = editing.takeTyped() else { return }
        set(typed.parameter, text: typed.text, at: typed.index)
    }

    public func focusSeries(_ series: Int, at index: Int) {
        guard isEditing else { return }
        editing.focus(series, at: index)
    }

    public func chooseRep(_ value: Int, series: Int, at index: Int) {
        edit(index) { $0.setRep(at: series, to: value) }
    }

    func endEditing() {
        drafts = nil
        editBase = nil
        editing.reset()
        isDiscardPromptPresented = false
    }

    /// En solo lectura no hace nada.
    private func edit(_ index: Int, _ change: (inout ExerciseLog) -> Void) {
        commitTyping()
        guard var drafts, drafts.indices.contains(index) else { return }
        change(&drafts[index])
        self.drafts = drafts
        editing.validationErrors[index] = nil
    }
}

import Domain
import Presentation

/// El selector de ejercicios del entreno en curso: añadir, cambiar por otro, crear uno nuevo y el
/// cambio recíproco que se ofrece después de cambiar.
extension TodayModel {
    public var picker: Picker? {
        guard let purpose = pickerPurpose, let session = activeSession else { return nil }
        switch purpose {
        case .add: return addPicker(session)
        case .swap(let index): return swapPicker(session, at: index)
        }
    }

    private func addPicker(_ session: Session) -> Picker {
        let candidates = data.addCandidates(on: today)
        let canCreate = !pickerOneOff
        let typed = pickerQuery.trimmingWhitespace()
        let creatable = canCreate && !typed.isEmpty && !data.catalog.hasExercise(named: typed)
        return Picker(purpose: .add, title: TodayText.addTitle(data.routines.name(of: session.routineID)), subtitle: nil,
                      sections: [section(nil, candidates, showsGroup: true, in: session)].compactMap(\.self),
                      offersOneOff: true, isOneOff: pickerOneOff, canCreate: canCreate,
                      searchCreateLabel: creatable ? TodayText.createNamed(typed) : nil,
                      offersNewExercise: canCreate && typed.isEmpty)
    }

    private func swapPicker(_ session: Session, at index: Int) -> Picker {
        let replaced = session.logs[index].exerciseID
        let present = Set(session.logs.map(\.exerciseID))
        let candidates = data.catalog.swapCandidates(data.catalog.all.filter { !present.contains($0.id) }, replacing: replaced,
                                                     routines: data.routines, currentRoutine: session.routineID)
        // Sin grupo propio no hay "mismo grupo": una sola sección, sin título.
        let sections = candidates.group.map { group in
            [section(GroupText.name(group), candidates.sameGroup, showsGroup: false, in: session),
             section(TodayText.otherGroupsSection, candidates.others, showsGroup: true, in: session)]
        } ?? [section(nil, candidates.others, showsGroup: true, in: session)]
        return Picker(purpose: .swap(index: index), title: TodayText.swapTitle,
                      subtitle: TodayText.swapSubtitle(data.catalog.name(of: replaced)),
                      sections: sections.compactMap(\.self), offersOneOff: false, isOneOff: false, canCreate: false,
                      searchCreateLabel: nil, offersNewExercise: false)
    }

    /// Los de `exercises` que casan con lo buscado; `nil` si no queda ninguno.
    private func section(_ title: String?, _ exercises: [Exercise], showsGroup: Bool, in session: Session) -> PickerSection? {
        let needle = pickerQuery.trimmingWhitespace().searchFolded
        let matching = needle.isEmpty ? exercises : exercises.filter { $0.name.searchFolded.contains(needle) }
        let rows = matching.map { exercise in
            let routines = data.routines.others(than: session.routineID, containing: exercise.id).map(\.name)
            return PickerRow(exercise: exercise, detail: TodayText.pickerDetail(group: showsGroup ? GroupText.name(exercise.group) : nil,
                                                                                routines: routines))
        }
        return rows.isEmpty ? nil : PickerSection(title: title, rows: rows)
    }

    /// "+ Ejercicio".
    public func openAddPicker() {
        guard activeSession != nil else { return }
        openPicker(.add)
    }

    /// Hay algún ejercicio del catálogo fuera del entreno: si no, «Cambiar por otro» no se ofrece.
    public var canSwap: Bool { data.hasSwapCandidates(on: today) }

    /// "Cambiar por otro".
    public func openSwapPicker(at index: Int) {
        guard canSwap, let session = activeSession, session.logs.indices.contains(index) else { return }
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
        await commitTyping()
        guard let purpose = pickerPurpose else { return }
        pickerPurpose = nil
        switch purpose {
        case .add: await add(exercise, oneOff: pickerOneOff)
        case .swap(let index): await swap(at: index, to: exercise)
        }
    }

    private func add(_ exercise: ExerciseID, oneOff: Bool) async {
        var data = data
        guard data.addToWorkout(exercise, oneOff: oneOff, on: today) else { return }
        await app.update(data)
    }

    // MARK: - Crear

    /// El nombre escrito en la pantalla de crear deja crear (la ✓ encendida).
    public var canCreateExercise: Bool { !createName.trimmingWhitespace().isEmpty }

    /// "Crear nuevo ejercicio" desde el selector, sin nada buscado: su pantalla, vacía y sin mensaje
    /// de error (repaso de la HIG, 2026-10-28; antes, una alerta con un campo).
    public func openCreate() {
        createName = ""
        createGroup = nil
        createMessage = nil
        isCreatePresented = true
    }

    /// "Crear «Press Arnold»": lo buscado, de un toque.
    public func createFromSearch() async {
        guard picker?.searchCreateLabel != nil else { return }
        createName = pickerQuery.trimmingWhitespace()
        createGroup = nil
        await createExercise()
    }

    /// "Crear": siempre entra en la rutina. Si ya existe, la pantalla sigue abierta con el nombre y
    /// lo dice.
    public func createExercise() async {
        let name = createName.trimmingWhitespace()
        guard !name.isEmpty else {
            isCreatePresented = false
            return
        }
        var data = data
        guard let id = data.createExercise(named: name, group: createGroup) else {
            createMessage = TodayText.alreadyExists
            isCreatePresented = true
            return
        }
        createMessage = nil
        isCreatePresented = false
        pickerPurpose = nil
        createName = ""
        createGroup = nil
        guard data.addToWorkout(id, oneOff: false, on: today) else { return }
        await app.update(data)
    }

    // MARK: - Cambiar por otro

    private func swap(at index: Int, to exercise: ExerciseID) async {
        guard var session = activeSession, session.logs.indices.contains(index) else { return }
        let outgoing = session.logs[index].exerciseID
        let swapped: ExerciseLog
        do {
            swapped = try session.swapExercise(at: index, to: exercise, seed: data.history.bestRecentSeed(for: exercise, today: today))
        } catch {
            // `.duplicate` no llega: el selector ya quita los ejercicios del entreno.
            return
        }
        var data = data
        data.history.replace(session)
        openExercise = exercise
        editing.unfocus()
        await app.update(data)
        if swapped.swappedFrom != nil { offerReciprocal(from: session.routineID, new: exercise, outgoing: outgoing) }
    }

    /// Si el ejercicio nuevo es de otra rutina (y solo de una) que aún no se ha hecho esta semana,
    /// se ofrece hacer el cambio inverso allí la próxima vez.
    private func offerReciprocal(from routine: RoutineID, new: ExerciseID, outgoing: ExerciseID) {
        guard let (target, swap) = data.reciprocalSwap(from: routine, new: new, outgoing: outgoing, on: today) else { return }
        let targetName = data.routines.name(of: target)
        reciprocalOffer = ReciprocalOffer(
            routine: target, swap: swap, title: TodayText.reciprocalTitle,
            message: TodayText.reciprocalMessage(new: data.catalog.name(of: new), outgoing: data.catalog.name(of: outgoing), routine: targetName),
            acceptLabel: TodayText.reciprocalAccept(targetName)
        )
    }

    /// Recibe la oferta que se acepta, no la lee de `reciprocalOffer`: SwiftUI cierra la alerta
    /// (`declineReciprocal`) antes de ejecutar la acción del botón.
    public func acceptReciprocal(_ offer: ReciprocalOffer) async {
        reciprocalOffer = nil
        var data = data
        data.pendingSwaps[offer.routine] = offer.swap
        await app.update(data)
        app.notice = TodayText.reciprocalScheduled(data.routines.name(of: offer.routine))
    }

    public func declineReciprocal() {
        reciprocalOffer = nil
    }
}

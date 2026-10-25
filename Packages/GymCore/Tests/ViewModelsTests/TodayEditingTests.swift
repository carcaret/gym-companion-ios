import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// Port por comportamiento de los e2e de cambiar, quitar, saltar y añadir puntuales, de los
// récords, la validación, la vista de entreno terminado y los botones de navegación de Hoy.

@MainActor
private func swap(_ today: TodayHarness, at index: Int, to exercise: ExerciseID) async {
    today.model.toggleCard(today.model.activeCards[index].exerciseID)
    today.model.openSwapPicker(at: index)
    await today.model.choose(exercise)
}

// tests/e2e/workout-swap.spec.js
@MainActor
@Suite("swap puntual de ejercicio en entreno activo")
struct WorkoutSwapTests {
    @Test("1 — cambiar ejercicio actualiza el título del card")
    func title() async {
        let today = await TodayHarness.make()
        await today.start()
        await swap(today, at: 0, to: "sentadilla")
        #expect(today.model.activeCards[0].title == "Sentadilla")
    }

    @Test("2 — log en localStorage tiene swappedFrom correcto")
    func swappedFrom() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await swap(today, at: 0, to: "sentadilla")
        let log = try #require(await today.savedToday?.logs[0])
        #expect(log.exerciseID == "sentadilla")
        #expect(log.swappedFrom == "press_banca")
    }

    @Test("3 — finalizar entreno → historial muestra el ejercicio sustituto")
    func finishShowsSubstitute() async {
        let today = await TodayHarness.make()
        await today.start()
        await swap(today, at: 0, to: "sentadilla")
        await today.finish()
        #expect(today.model.completedRows.first?.title == "Sentadilla")
        #expect(await today.saved?.history.session(on: today.today)?.logs.first?.exerciseID == "sentadilla")
    }

    @Test("4 — DIA1 sigue con el ejercicio original tras el swap (regresión clave)")
    func routineIntact() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await swap(today, at: 0, to: "sentadilla")
        let routine = try #require(await today.saved?.routines[0].exerciseIDs)
        #expect(routine.contains("press_banca"))
        #expect(!routine.contains("sentadilla"))
    }

    @Test("5 — modal de swap excluye los ejercicios ya presentes en el entreno")
    func excludesPresent() async throws {
        let today = await TodayHarness.make()
        await today.start()
        today.model.openSwapPicker(at: 0)
        let names = try #require(today.model.picker?.exercises.map(\.name))
        #expect(!names.contains("Press Banca"))
        #expect(!names.contains("Curl Bíceps"))
        #expect(names.contains("Sentadilla"))
    }

    @Test("6 — swap A→B→A: swappedFrom desaparece al volver al original")
    func backToOriginal() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await swap(today, at: 0, to: "sentadilla")
        #expect(await today.savedToday?.logs[0].swappedFrom == "press_banca")
        today.model.openSwapPicker(at: 0)
        await today.model.choose("press_banca")
        let log = try #require(await today.savedToday?.logs[0])
        #expect(log.exerciseID == "press_banca")
        #expect(log.swappedFrom == nil)
    }

    @Test("7 — quitar de rutina sobre log swapped: log desaparece, plantilla DIA1 intacta")
    func removeSwapped() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await swap(today, at: 0, to: "sentadilla")
        await today.model.requestRemoval(at: 0)
        try await today.model.confirmRemoval(#require(today.model.removalPrompt))
        #expect(today.model.activeCards.count == 2)
        #expect(today.model.activeCards[0].title == "Curl Bíceps")
        let routine = try #require(await today.saved?.routines[0].exerciseIDs)
        #expect(routine.contains("press_banca"))
        #expect(!routine.contains("sentadilla"))
    }

    @Test("8 — tras swap A→B, \"+ Ejercicio\" no ofrece B (fix bug duplicado)")
    func addExcludesSwapped() async {
        let today = await TodayHarness.make()
        await today.start()
        await swap(today, at: 0, to: "sentadilla")
        today.model.openAddPicker()
        #expect(today.model.picker?.title.contains("Añadir") == true)
        #expect(today.model.picker?.exercises.contains { $0.name == "Sentadilla" } == false)
    }
}

// tests/e2e/workout-swap-order.spec.js
@MainActor
@Suite("orden del modal de swap de ejercicio")
struct WorkoutSwapOrderTests {
    private func data() -> TrainingData {
        TrainingData(
            catalog: Catalog([
                Exercise(id: "press_banca", name: "Press Banca", group: .pecho),
                Exercise(id: "curl_biceps", name: "Curl Bíceps", group: .biceps),
                Exercise(id: "apertura", name: "Apertura", group: .pecho),
                Exercise(id: "press_inclinado", name: "Press Inclinado", group: .pecho),
                Exercise(id: "sentadilla", name: "Sentadilla", group: .piernas),
                Exercise(id: "plancha", name: "Plancha", group: .core),
            ]),
            routines: [
                Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl_biceps"]),
                Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["sentadilla", "apertura"]),
                Routine(id: "DIA3", name: "Full Body - Día 3"),
            ]
        )
    }

    private func openSwap() async -> TodayHarness {
        let today = await TodayHarness.make(data())
        await today.start()
        today.model.toggleCard("press_banca")
        today.model.openSwapPicker(at: 0)
        return today
    }

    private func names(_ today: TodayHarness) -> [String] {
        today.model.picker?.exercises.map(\.name) ?? []
    }

    @Test("1 — ejercicios de la rutina activa (DIA1) no aparecen en el modal")
    func excludesRoutine() async {
        let names = names(await openSwap())
        #expect(!names.contains("Press Banca"))
        #expect(!names.contains("Curl Bíceps"))
    }

    @Test("2 — ejercicios de otros días SÍ aparecen en el modal")
    func otherDays() async {
        let names = names(await openSwap())
        #expect(names.contains("Sentadilla"))
        #expect(names.contains("Apertura"))
    }

    @Test("3 — tier 0 primero: mismo grupo + en otra rutina (Apertura, pecho, DIA2)")
    func tier0() async { #expect(names(await openSwap())[0] == "Apertura") }

    @Test("4 — tier 1 segundo: mismo grupo + sin rutina (Press Inclinado, pecho)")
    func tier1() async { #expect(names(await openSwap())[1] == "Press Inclinado") }

    @Test("5 — tier 2 tercero: distinto grupo + en otra rutina (Sentadilla, piernas, DIA2)")
    func tier2() async { #expect(names(await openSwap())[2] == "Sentadilla") }

    @Test("6 — tier 3 último: distinto grupo + sin rutina (Plancha, core)")
    func tier3() async { #expect(names(await openSwap())[3] == "Plancha") }

    @Test("7 — orden completo: [Apertura, Press Inclinado, Sentadilla, Plancha]")
    func full() async { #expect(names(await openSwap()) == ["Apertura", "Press Inclinado", "Sentadilla", "Plancha"]) }

    @Test("8 — se puede seleccionar un ejercicio de cualquier tier y el swap funciona")
    func anyTier() async {
        let today = await openSwap()
        await today.model.choose("sentadilla")
        #expect(today.model.activeCards[0].title == "Sentadilla")
    }

    @Test("9 — tras swap, la rutina DIA1 sigue intacta en localStorage")
    func routineIntact() async throws {
        let today = await openSwap()
        await today.model.choose("apertura")
        let routine = try #require(await today.saved?.routines[0].exerciseIDs)
        #expect(routine.contains("press_banca"))
        #expect(!routine.contains("apertura"))
    }

    @Test("10 — búsqueda filtra: con \"press\" solo queda visible Press Inclinado")
    func search() async {
        let today = await openSwap()
        today.model.pickerQuery = "press"
        #expect(today.model.picker?.exercises.map(\.id) == ["press_inclinado"])
    }
}

// tests/e2e/workout-reciprocal-swap.spec.js
@MainActor
@Suite("swap recíproco entre días de rutina")
struct ReciprocalSwapTests {
    @Test("1 — swap desde único match en otro día ofrece modal recíproco; confirmar crea el pendiente")
    func offerAndAccept() async throws {
        let today = await TodayHarness.make()
        await today.start("DIA2")
        await swap(today, at: 0, to: "curl_biceps")
        let offer = try #require(today.model.reciprocalOffer)
        #expect(offer.title == "Intercambio recíproco")
        #expect(offer.message.contains("Full Body - Día 1"))
        await today.model.acceptReciprocal(offer)
        let pending = try #require(await today.saved?.pendingSwaps["DIA1"])
        #expect(pending.from == "curl_biceps")
        #expect(pending.to == "sentadilla")
    }

    /// SwiftUI cierra la alerta (y la descarta) antes de ejecutar la acción del botón.
    @Test("aceptar desde la alerta, que se cierra antes de la acción, crea el pendiente")
    func acceptAfterAlertDismissal() async throws {
        let today = await TodayHarness.make()
        await today.start("DIA2")
        await swap(today, at: 0, to: "curl_biceps")
        let offer = try #require(today.model.reciprocalOffer)
        today.model.declineReciprocal()
        await today.model.acceptReciprocal(offer)
        #expect(await today.saved?.pendingSwaps["DIA1"] != nil)
    }

    @Test("2 — declinar el modal (No) no crea ningún pendiente")
    func decline() async {
        let today = await TodayHarness.make()
        await today.start("DIA2")
        await swap(today, at: 0, to: "curl_biceps")
        #expect(today.model.reciprocalOffer != nil)
        today.model.declineReciprocal()
        #expect(await today.saved?.pendingSwaps["DIA1"] == nil)
    }

    @Test("3 — swap ambiguo (ejercicio en 2+ días) no ofrece modal recíproco (regresión)")
    func ambiguous() async {
        let today = await TodayHarness.make()
        await today.start("DIA1")
        await swap(today, at: 0, to: "sentadilla")
        #expect(today.model.activeCards[0].title == "Sentadilla")
        #expect(today.model.reciprocalOffer == nil)
        #expect(await today.saved?.pendingSwaps.isEmpty == true)
    }

    /// `createPendingSwapOnDia1`: DIA2 con curl en vez de sentadilla, aceptar, terminar y volver.
    private func pendingOnDia1() async throws -> TodayHarness {
        let today = await TodayHarness.make()
        await today.start("DIA2")
        await swap(today, at: 0, to: "curl_biceps")
        try await today.model.acceptReciprocal(#require(today.model.reciprocalOffer))
        await today.finish()
        today.model.backFromCompleted()
        return today
    }

    @Test("4 — selector de días muestra aviso del intercambio pendiente")
    func note() async throws {
        let today = try await pendingOnDia1()
        let note = try #require(today.model.routineRows.first { $0.id == "DIA1" }?.pendingNote)
        #expect(note.contains("Sentadilla"))
        #expect(note.contains("Curl Bíceps"))
    }

    @Test("5 — al iniciar el día destino, el ejercicio queda sustituido y el pendiente sigue vivo")
    func applied() async throws {
        let today = try await pendingOnDia1()
        await today.start("DIA1")
        #expect(today.model.activeCards.map(\.title) == ["Press Banca", "Sentadilla", "Ejercicio Sin Historial"])
        #expect(await today.saved?.pendingSwaps["DIA1"] != nil)
    }

    @Test("7 — al terminar el entreno del día destino, el pendiente se borra")
    func clearedOnFinish() async throws {
        let today = try await pendingOnDia1()
        await today.start("DIA1")
        #expect(await today.saved?.pendingSwaps["DIA1"] != nil)
        await today.finish()
        #expect(today.model.stage == .completed)
        #expect(await today.saved?.pendingSwaps["DIA1"] == nil)
    }

    @Test("9 — revertir un swap (A→B→A) no vuelve a ofrecer el modal recíproco")
    func revert() async throws {
        let today = await TodayHarness.make()
        await today.start("DIA2")
        await swap(today, at: 0, to: "curl_biceps")
        #expect(today.model.reciprocalOffer != nil)
        try await today.model.acceptReciprocal(#require(today.model.reciprocalOffer))
        let first = try #require(await today.saved?.pendingSwaps["DIA1"])
        #expect(first.from == "curl_biceps")
        #expect(first.to == "sentadilla")
        today.model.openSwapPicker(at: 0)
        await today.model.choose("sentadilla")
        #expect(today.model.activeCards[0].title == "Sentadilla")
        #expect(today.model.reciprocalOffer == nil)
        #expect(await today.saved?.pendingSwaps["DIA1"] == first)
    }
}

@MainActor
@Suite("swap recíproco — pendiente caducado")
struct ExpiredReciprocalSwapTests {
    @Test("6 — pendiente con semana caducada no se aplica y se limpia al iniciar")
    func expired() async {
        var data = PWATestDB.data
        data.pendingSwaps = ["DIA1": PendingSwap(from: "curl_biceps", to: "sentadilla", weekStart: LocalDate(iso: "2000-01-03")!)]
        let today = await TodayHarness.make(data)
        await today.start("DIA1")
        #expect(today.model.activeCards[1].title == "Curl Bíceps")
        #expect(await today.saved?.pendingSwaps["DIA1"] == nil)
    }
}

@MainActor
@Suite("swap recíproco — día destino ya hecho esta semana")
struct DoneThisWeekReciprocalSwapTests {
    @Test("8 — DIA1 ya hecho esta semana: swap hacia su ejercicio único no ofrece modal recíproco")
    func doneThisWeek() async {
        var data = PWATestDB.data
        data.history.append(Session(date: SyncFixtures.today.weekStart, routineID: "DIA1", completed: true, logs: [
            ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 10, 10], weight: 60),
            ExerciseLog(exerciseID: "curl_biceps", series: 3, targetReps: 12, actualReps: [12, 12, 12], weight: 15),
        ]))
        let today = await TodayHarness.make(data)
        await today.start("DIA2")
        await swap(today, at: 0, to: "curl_biceps")
        #expect(today.model.activeCards[0].title == "Curl Bíceps")
        #expect(today.model.reciprocalOffer == nil)
        #expect(await today.saved?.pendingSwaps.isEmpty == true)
    }
}

// tests/e2e/workout-remove-exercise.spec.js
@MainActor
@Suite("Quitar ejercicio de rutina durante entreno")
struct RemoveExerciseTests {
    @Test("botón Quitar de rutina visible al expandir card durante entreno")
    func label() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        #expect(today.model.activeCards[0].removeLabel == "Quitar de rutina")
        #expect(today.model.activeCards[0].isEditable)
    }

    @Test("clic en Quitar abre modal con nombre del ejercicio")
    func prompt() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.requestRemoval(at: 0)
        let prompt = try #require(today.model.removalPrompt)
        #expect(prompt.title == "¿Quitar ejercicio?")
        #expect(prompt.message.contains("Press Banca"))
    }

    @Test("confirmar elimina card del entreno y ejercicio de DB.routines")
    func confirm() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.requestRemoval(at: 0)
        try await today.model.confirmRemoval(#require(today.model.removalPrompt))
        #expect(today.model.activeCards.count == 2)
        #expect(today.model.activeCards[0].title == "Curl Bíceps")
        #expect(await today.saved?.routines[0].exerciseIDs.contains("press_banca") == false)
    }

    /// SwiftUI cierra el diálogo (y lo descarta) antes de ejecutar la acción del botón.
    @Test("quitar desde el diálogo, que se cierra antes de la acción, quita el ejercicio")
    func confirmAfterDialogDismissal() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.requestRemoval(at: 0)
        let prompt = try #require(today.model.removalPrompt)
        today.model.cancelRemoval()
        await today.model.confirmRemoval(prompt)
        #expect(today.model.activeCards.count == 2)
        #expect(await today.saved?.routines[0].exerciseIDs.contains("press_banca") == false)
    }

    @Test("cancelar mantiene el ejercicio en el entreno y en DB.routines")
    func cancel() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.requestRemoval(at: 0)
        today.model.cancelRemoval()
        #expect(today.model.activeCards.count == 3)
        #expect(await today.saved?.routines[0].exerciseIDs.contains("press_banca") == true)
    }
}

// tests/e2e/skip-exercise.spec.js
@MainActor
@Suite("Saltar ejercicio")
struct SkipExerciseTests {
    @Test("saltar y reactivar un ejercicio en entreno activo")
    func toggle() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        #expect(today.model.activeCards[0].skipLabel == "Saltar")
        await today.model.toggleSkip(at: 0)
        #expect(today.model.activeCards[0].isSkipped)
        #expect(today.model.activeCards[0].skipLabel == "Reactivar")
        await today.model.toggleSkip(at: 0)
        #expect(today.model.activeCards.allSatisfy { !$0.isSkipped })
        #expect(today.model.activeCards[0].skipLabel == "Saltar")
    }

    @Test("la card saltada mantiene el fondo al expandir")
    func keepsOpen() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        await today.model.toggleSkip(at: 0)
        #expect(today.model.activeCards[0].isSkipped)
        #expect(today.model.activeCards[0].isOpen)
    }

    @Test("skipped se persiste en la DB de la sesión")
    func persisted() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.toggleSkip(at: 0)
        #expect(await today.savedToday?.logs.filter(\.skipped).count == 1)
    }

    @Test("finalizar con un saltado cuenta como completo")
    func finishWithSkipped() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.toggleSkip(at: 0)
        await today.finish()
        #expect(await today.savedToday?.completed == true)
    }

    // El historial (#10) pinta igual que la vista de entreno terminado (`SummaryRow`).
    @Test("un ejercicio saltado se ve con fondo en historial, sin botón")
    func skippedInSummary() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.toggleSkip(at: 0)
        await today.finish()
        #expect(today.model.completedRows.first?.isSkipped == true)
    }
}

// tests/e2e/one-off-exercise.spec.js
@MainActor
@Suite("Ejercicio puntual (solo esta sesión)")
struct OneOffExerciseTests {
    private func started() async -> TodayHarness {
        let today = await TodayHarness.make()
        await today.start()
        return today
    }

    @Test("1 — el chip aparece en el modal y arranca apagado")
    func chipOff() async {
        let today = await started()
        today.model.openAddPicker()
        #expect(today.model.picker?.offersOneOff == true)
        #expect(today.model.picker?.isOneOff == false)
    }

    @Test("2 — chip apagado: el ejercicio entra en la rutina (comportamiento de siempre)")
    func off() async throws {
        let today = await started()
        today.model.openAddPicker()
        await today.model.choose("sentadilla")
        #expect(await today.saved?.routines[0].exerciseIDs.contains("sentadilla") == true)
        let logs = try #require(await today.savedToday?.logs)
        #expect(logs.count == 4)
        #expect(logs[3].exerciseID == "sentadilla")
        #expect(!logs[3].oneOff)
    }

    @Test("3 — chip encendido: entra en el entreno pero NO en la rutina")
    func on() async throws {
        let today = await started()
        today.model.openAddPicker()
        today.model.toggleOneOff()
        #expect(today.model.picker?.isOneOff == true)
        await today.model.choose("sentadilla")
        #expect(today.app.notice?.text.contains("solo para hoy") == true)
        #expect(today.model.activeCards.count == 4)
        #expect(await today.saved?.routines[0].exerciseIDs == ["press_banca", "curl_biceps", "ejercicio_sin_historial"])
        let logs = try #require(await today.savedToday?.logs)
        #expect(logs[3].exerciseID == "sentadilla")
        #expect(logs[3].oneOff)
    }

    @Test("4 — chip encendido oculta \"Crear nuevo ejercicio\"; apagarlo lo devuelve")
    func createHidden() async {
        let today = await started()
        today.model.openAddPicker()
        #expect(today.model.picker?.canCreate == true)
        today.model.toggleOneOff()
        #expect(today.model.picker?.canCreate == false)
        today.model.toggleOneOff()
        #expect(today.model.picker?.canCreate == true)
    }

    @Test("5 — la card puntual dice \"Quitar\" y se borra sin modal ni tocar la rutina")
    func removeOneOff() async {
        let today = await started()
        today.model.openAddPicker()
        today.model.toggleOneOff()
        await today.model.choose("sentadilla")
        #expect(today.model.activeCards[3].removeLabel == "Quitar")
        await today.model.requestRemoval(at: 3)
        #expect(today.model.removalPrompt == nil)
        #expect(today.model.activeCards.count == 3)
        #expect(await today.saved?.routines[0].exerciseIDs == ["press_banca", "curl_biceps", "ejercicio_sin_historial"])
    }

    @Test("6 — reordenar con un puntual presente no mete el puntual en la rutina")
    func reorderWithOneOff() async {
        let today = await started()
        today.model.openAddPicker()
        today.model.toggleOneOff()
        await today.model.choose("sentadilla")
        await today.model.reorder(from: 0, to: 1)
        #expect(today.app.notice?.text.contains("Orden actualizado") == true)
        #expect(await today.saved?.routines[0].exerciseIDs == ["curl_biceps", "press_banca", "ejercicio_sin_historial"])
        #expect(await today.savedToday?.logs.map(\.exerciseID) == ["curl_biceps", "press_banca", "ejercicio_sin_historial", "sentadilla"])
    }

    @Test("7 — al finalizar, el puntual queda en el historial y la rutina sigue limpia")
    func finish() async {
        let today = await started()
        today.model.openAddPicker()
        today.model.toggleOneOff()
        await today.model.choose("sentadilla")
        await today.finish()
        #expect(today.model.stage == .completed)
        #expect(await today.savedToday?.logs.map(\.exerciseID).contains("sentadilla") == true)
        #expect(await today.saved?.routines[0].exerciseIDs.contains("sentadilla") == false)
    }
}

// tests/e2e/records.spec.js
@MainActor
@Suite("Deteccion de PRs")
struct RecordsTests {
    @Test("subir peso por encima del historico y completar reps muestra badge PR")
    func record() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.set(.weight, text: "100", at: 0)
        await today.model.chooseRep(10, series: 0, at: 0)
        #expect(today.model.activeCards[0].hasRecord)
        #expect(today.model.hasRecord)
    }

    @Test("mismos valores que historico NO muestra badge")
    func noRecord() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.chooseRep(10, series: 0, at: 0)
        await today.model.chooseRep(10, series: 1, at: 0)
        await today.model.chooseRep(8, series: 2, at: 0)
        #expect(!today.model.activeCards[0].hasRecord)
    }
}

// tests/e2e/validation-workout.spec.js
@MainActor
@Suite("Validación en vista Hoy")
struct TodayValidationTests {
    @Test("todas las reps completas → finalizar funciona normalmente")
    func complete() async {
        let today = await TodayHarness.make()
        await today.start()
        for card in today.model.activeCards { today.model.toggleCard(card.exerciseID) }
        await today.finish()
        #expect(today.model.stage == .completed)
    }

    @Test("series 0 (manual input) → se clampea a 1 por setParam")
    func seriesClamped() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.set(.series, text: "0", at: 0)
        #expect(today.model.activeCards[0].series == 1)
    }
}

@MainActor
@Suite("Validación al terminar el entreno")
struct FinishValidationTests {
    @Test("con una serie vacía no termina: avisa, marca la serie y abre su tarjeta")
    func incomplete() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.model.adjust(.series, direction: 1, at: 1)
        // La serie nueva arranca con el objetivo; se vacía a mano para que falte.
        await today.model.chooseRep(12, series: 0, at: 1)
        var data = today.app.data!
        var session = data.history.session(on: today.today)!
        session.logs[1].actualReps[3] = nil
        data.history[data.history.firstIndex { $0.date == today.today }!] = session
        await today.app.update(data)

        await today.finish()
        #expect(today.model.stage == .active)
        #expect(today.app.notice == TodayText.incomplete)
        #expect(today.model.activeCards[1].errors == [.missingRep(index: 3)])
        #expect(today.model.activeCards[1].cells[3].hasError)
        #expect(today.model.activeCards.map(\.isOpen) == [false, true, false])
    }

    @Test("terminar sin poder subir a GitHub avisa de que queda guardado en el iPhone")
    func savedLocally() async {
        let today = await TodayHarness.make(configured: true)
        await today.harness.remote.fail(fetch: .unreachable, push: .unreachable)
        await today.start()
        await today.finish()
        #expect(today.model.stage == .completed)
        #expect(today.sync.isSavedLocallyPresented)
    }
}

// tests/e2e/workout-completed-view.spec.js
@MainActor
@Suite("Vista de entreno completado")
struct CompletedViewTests {
    private func completed() async -> TodayHarness {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        return today
    }

    @Test("las cards usan formato de historial (compact-card + card-title/subtitle)")
    func historyFormat() async {
        let rows = await completed().model.completedRows
        #expect(!rows.isEmpty)
        #expect(rows.allSatisfy { !$0.title.isEmpty && !$0.subtitle.isEmpty })
    }

    @Test("las cards NO tienen botón de editar")
    func notEditable() async {
        let today = await completed()
        #expect(today.model.activeCards.isEmpty)
        #expect(!today.model.canReorder)
    }

    @Test("el subtitle muestra peso, series y reps formateados")
    func subtitle() async {
        let subtitle = await completed().model.completedRows[0].subtitle
        #expect(subtitle.contains("3×10"))
    }

    @Test("toast de inicio no tiene emoji")
    func startNotice() async {
        let today = await TodayHarness.make()
        await today.start()
        #expect(today.app.notice?.text == "¡Entreno iniciado!")
    }

    @Test("toast de fin no tiene emoji")
    func finishNotice() async {
        let today = await completed()
        #expect(today.app.notice?.text.contains("¡Entreno completado!") == true)
        #expect(today.app.notice?.text.contains("🎉") == false)
    }

    @Test("la vista completada coincide en estructura con el detalle del historial")
    func matchesHistory() async throws {
        let today = await completed()
        let session = try #require(await today.savedToday)
        #expect(today.model.completedRows.map(\.subtitle) == session.logs.map(LogText.summary))
    }

    @Test("navegar entre múltiples pestañas y volver muestra el selector (no el resumen)")
    func severalTabs() async {
        let today = await completed()
        today.model.appear()
        #expect(today.model.stage == .selector)
        today.model.appear()
        #expect(today.model.stage == .selector)
        #expect(today.model.completedRows.isEmpty)
    }

    @Test("navegar a otra pestaña y volver muestra el selector (no el resumen completado)")
    func otherTab() async {
        let today = await completed()
        today.model.appear()
        #expect(today.model.stage == .selector)
    }

    @Test("vista completada: existe botón #back-to-selector-btn")
    func backExists() async {
        #expect(await completed().model.stage == .completed)
    }

    @Test("vista completada: botón Volver tiene texto \"← Volver a rutinas\"")
    func backLabel() {
        #expect(TodayText.backToRoutines == "Volver a rutinas")
    }

    @Test("durante el entreno activo NO existe el botón Volver a rutinas")
    func noBackWhileActive() async {
        let today = await TodayHarness.make()
        await today.start()
        #expect(today.model.stage == .active)
    }

    @Test("tras pulsar Volver, aparece el selector de rutinas con título \"Rutinas\"")
    func back() async {
        let today = await completed()
        today.model.backFromCompleted()
        #expect(today.model.stage == .selector)
        #expect(today.model.title == "Rutinas")
    }

    @Test("sin pulsar Volver, el resumen sigue visible al recargar la vista (botón Volver presente)")
    func staysCompleted() async {
        let today = await completed()
        #expect(today.model.stage == .completed)
        #expect(today.model.title == "Full Body - Día 1")
    }
}

// tests/e2e/view-nav-buttons.spec.js, la parte de Hoy (la del historial va con #10).
@MainActor
@Suite("Botones de navegación en vistas (Volver + Ejercicio)")
struct TodayNavigationButtonsTests {
    @Test("routine preview: botón Volver tiene texto \"← Volver\" y estilo btn-secondary")
    func backLabel() {
        #expect(TodayText.back == "Volver")
    }

    @Test("routine preview: no existe botón + Ejercicio")
    func noAddInPreview() async {
        let today = await TodayHarness.make()
        today.model.select("DIA1")
        today.model.openAddPicker()
        #expect(today.model.picker == nil)
    }

    @Test("routine preview: botón Volver vuelve al selector de rutinas")
    func back() async {
        let today = await TodayHarness.make()
        today.model.select("DIA1")
        today.model.backToSelector()
        #expect(today.model.stage == .selector)
        #expect(today.model.previewCards.isEmpty)
    }

    @Test("completed view: botón Volver lleva al selector de rutinas")
    func completedBack() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        today.model.backFromCompleted()
        #expect(today.model.stage == .selector)
        #expect(!today.model.routineRows.isEmpty)
    }

    @Test("completed view: botón Volver actualiza el título a \"Rutinas\"")
    func completedTitle() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        today.model.backFromCompleted()
        #expect(today.model.title == "Rutinas")
    }

    @Test("completed view: botón Volver oculta la vista de completado")
    func completedHidden() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        today.model.backFromCompleted()
        #expect(today.model.completedRows.isEmpty)
    }

    @Test("completed view: desde selector tras volver, se puede seleccionar otra rutina")
    func selectAnother() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        today.model.backFromCompleted()
        #expect(today.model.routineRows.count == 3)
        today.model.select("DIA2")
        #expect(today.model.stage == .preview("DIA2"))
    }

    @Test("completed view: tras volver al selector y navegar a otra pestaña, volver a Hoy muestra el selector")
    func backAndTabs() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        today.model.backFromCompleted()
        today.model.appear()
        #expect(today.model.stage == .selector)
        #expect(today.model.completedRows.isEmpty)
    }
}

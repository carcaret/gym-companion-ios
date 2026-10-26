import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// Port por comportamiento de los e2e del entreno en curso. "La card abierta" es `isOpen`; el
// input de peso, `weight`; las celdas de serie, `cells`; los chips, `chips`.

// tests/e2e/workout-full.spec.js
@MainActor
@Suite("Workout flow completo")
struct WorkoutFlowTests {
    @Test("iniciar entreno y verificar que muestra cards de ejercicios")
    func cards() async {
        let today = await TodayHarness.make()
        await today.start()
        #expect(today.model.activeCards.count == 3)
    }

    @Test("ajustar peso (+1 escalon) se refleja en el input")
    func weightStep() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        let initial = today.model.activeCards[0].weight
        await today.model.adjust(.weight, direction: 1, at: 0)
        #expect(today.model.activeCards[0].weight == initial + ExerciseLog.weightStep(for: initial))
    }

    @Test("ajustar series (+1) añade nueva fila de rep")
    func addSeries() async {
        let today = await TodayHarness.make()
        await today.start()
        let initial = today.model.activeCards[0].cells.count
        await today.model.adjust(.series, direction: 1, at: 0)
        #expect(today.model.activeCards[0].cells.count == initial + 1)
    }

    @Test("decrementar series elimina fila")
    func removeSeries() async {
        let today = await TodayHarness.make()
        await today.start()
        let initial = today.model.activeCards[0].cells.count
        await today.model.adjust(.series, direction: -1, at: 0)
        #expect(today.model.activeCards[0].cells.count == initial - 1)
    }

    @Test("completar rep de serie 1 guarda el valor")
    func chooseRep() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        today.model.focusSeries(0, at: 0)
        #expect(today.model.activeCards[0].chips.map(\.value).contains(12))
        await today.model.chooseRep(12, series: 0, at: 0)
        #expect(today.model.activeCards[0].cells[0].text == "12")
        #expect(await today.savedToday?.logs[0].actualReps[0] == 12)
    }

    @Test("finalizar entreno con reps completas marca completado")
    func finish() async {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        #expect(today.model.stage == .completed)
        #expect(TodayText.completedStatus.contains("completado"))
    }

    @Test("finalizar entreno y verificar en historial")
    func finishInHistory() async throws {
        let today = await TodayHarness.make()
        await today.start()
        await today.finish()
        let saved = try #require(await today.saved)
        #expect(saved.history.count >= 3)
        #expect(saved.history.session(on: today.today)?.completed == true)
    }

    @Test("entreno en curso se guarda en localStorage")
    func savedWhileActive() async throws {
        let today = await TodayHarness.make()
        await today.start()
        let session = try #require(await today.savedToday)
        #expect(!session.completed)
        #expect(!session.logs.isEmpty)
    }
}

// tests/e2e/workout-accordion.spec.js
@MainActor
@Suite("Accordion: solo una card expandida a la vez")
struct WorkoutAccordionTests {
    private func started() async -> TodayHarness {
        let today = await TodayHarness.make()
        await today.start()
        return today
    }

    private func openIndices(_ today: TodayHarness) -> [Int] {
        today.model.activeCards.enumerated().filter { $0.element.isOpen }.map(\.offset)
    }

    @Test("todas las cards empiezan cerradas")
    func closed() async {
        #expect(openIndices(await started()).isEmpty)
    }

    @Test("clicar una card la expande")
    func expand() async {
        let today = await started()
        today.model.toggleCard("press_banca")
        #expect(openIndices(today) == [0])
    }

    @Test("clicar otra card cierra la primera y abre la nueva")
    func switchCard() async {
        let today = await started()
        today.model.toggleCard("press_banca")
        today.model.toggleCard("curl_biceps")
        #expect(openIndices(today) == [1])
    }

    @Test("clicar la card abierta la cierra (todas cerradas)")
    func closeOpen() async {
        let today = await started()
        today.model.toggleCard("press_banca")
        today.model.toggleCard("press_banca")
        #expect(openIndices(today).isEmpty)
    }

    @Test("solo hay una card-body.open como máximo en todo momento")
    func atMostOne() async {
        let today = await started()
        for (index, card) in today.model.activeCards.enumerated() {
            today.model.toggleCard(card.exerciseID)
            #expect(openIndices(today) == [index])
        }
    }

    @Test("la card abierta se preserva tras ajustar peso")
    func keepAfterWeight() async {
        let today = await started()
        today.model.toggleCard("press_banca")
        await today.model.adjust(.weight, direction: 1, at: 0)
        #expect(openIndices(today) == [0])
    }

    @Test("la card abierta se preserva tras modificar una rep")
    func keepAfterRep() async {
        let today = await started()
        today.model.toggleCard("press_banca")
        today.model.focusSeries(0, at: 0)
        await today.model.chooseRep(12, series: 0, at: 0)
        #expect(openIndices(today) == [0])
    }

    @Test("después de cerrar todas, se puede abrir cualquiera")
    func reopen() async {
        let today = await started()
        today.model.toggleCard("press_banca")
        today.model.toggleCard("press_banca")
        today.model.toggleCard("curl_biceps")
        #expect(openIndices(today) == [1])
    }

    // El chevron de la vista se pinta con `isOpen`.
    @Test("chevrons se sincronizan con el estado de la card")
    func chevrons() async {
        let today = await started()
        today.model.toggleCard("press_banca")
        #expect(today.model.activeCards.map(\.isOpen).prefix(2) == [true, false])
        today.model.toggleCard("curl_biceps")
        #expect(today.model.activeCards.map(\.isOpen).prefix(2) == [false, true])
        today.model.toggleCard("curl_biceps")
        #expect(today.model.activeCards.map(\.isOpen).prefix(2) == [false, false])
    }
}

@MainActor
@Suite("Selector de ejercicios: secciones y segunda línea")
struct PickerSectionsTests {
    /// Los datos de los e2e con otro ejercicio de bíceps, para que haya "mismo grupo" al cambiar el curl.
    private func harness() async -> TodayHarness {
        var data = PWATestDB.data
        data.catalog = Catalog(data.catalog.all + [Exercise(id: "curl_martillo", name: "Curl Martillo", group: .biceps)])
        let today = await TodayHarness.make(data)
        await today.start()
        return today
    }

    @Test("cambiar: el grupo del ejercicio primero y luego los demás, con el que se sustituye de subtítulo")
    func swapSections() async throws {
        let today = await harness()
        today.model.openSwapPicker(at: 1)
        let picker = try #require(today.model.picker)
        #expect(picker.subtitle == "En lugar de Curl Bíceps")
        #expect(picker.sections.map(\.title) == ["Bíceps", "Otros grupos"])
        #expect(picker.sections.map { $0.rows.map(\.id) } == [["curl_martillo"], ["sentadilla"]])
    }

    @Test("la segunda línea da las rutinas donde está y, fuera de su sección, el grupo")
    func details() async throws {
        let today = await harness()
        today.model.openSwapPicker(at: 1)
        let rows = try #require(today.model.picker?.sections.flatMap { $0.rows })
        #expect(rows.map(\.detail) == [nil, "Piernas · En Full Body - Día 2, Full Body - Día 3"])
    }

    @Test("buscar quita las secciones que se quedan vacías")
    func searchDropsEmptySections() async throws {
        let today = await harness()
        today.model.openSwapPicker(at: 1)
        today.model.pickerQuery = "sent"
        #expect(today.model.picker?.sections.map(\.title) == ["Otros grupos"])
    }

    @Test("cambiar un ejercicio sin grupo: una sola sección, sin título")
    func swapWithoutGroup() async throws {
        var data = PWATestDB.data
        data.catalog = Catalog(data.catalog.all.map { $0.id == "curl_biceps" ? Exercise(id: $0.id, name: $0.name) : $0 })
        let today = await TodayHarness.make(data)
        await today.start()
        today.model.openSwapPicker(at: 1)
        let picker = try #require(today.model.picker)
        #expect(picker.sections.map(\.title) == [nil])
        #expect(picker.exercises.map(\.id) == ["sentadilla"])
    }

    @Test("añadir: una sola sección, sin título ni subtítulo, con el grupo en cada fila")
    func addSection() async throws {
        let today = await harness()
        today.model.openAddPicker()
        let picker = try #require(today.model.picker)
        #expect(picker.subtitle == nil)
        #expect(picker.sections.map(\.title) == [nil])
        #expect(picker.sections.flatMap { $0.rows }.map(\.detail) == ["Bíceps", "Piernas · En Full Body - Día 2, Full Body - Día 3"])
    }
}

// tests/e2e/workout-open-state.spec.js
@MainActor
@Suite("Estado abierto de card tras swap / quitar / añadir")
struct WorkoutOpenStateTests {
    @Test("swap de la card abierta: queda abierta esa card con el nuevo ejercicio, no la siguiente")
    func swap() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("curl_biceps")
        today.model.openSwapPicker(at: 1)
        #expect(today.model.picker?.title == "Cambiar ejercicio")
        await today.model.choose("sentadilla")
        let cards = today.model.activeCards
        #expect(cards[1].title == "Sentadilla")
        #expect(cards.map(\.isOpen) == [false, true, false])
    }

    @Test("quitar la card abierta: no queda ninguna abierta (la siguiente no se abre sola)")
    func remove() async throws {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("curl_biceps")
        await today.model.requestRemoval(at: 1)
        try await today.model.confirmRemoval(#require(today.model.removalPrompt))
        let cards = today.model.activeCards
        #expect(cards.count == 2)
        #expect(cards[1].title == "Ejercicio Sin Historial")
        #expect(cards.allSatisfy { !$0.isOpen })
    }

    @Test("añadir ejercicio mantiene abierta la card actual y añade la nueva cerrada")
    func add() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        today.model.openAddPicker()
        #expect(today.model.picker?.title.contains("Añadir") == true)
        await today.model.choose("sentadilla")
        #expect(today.model.activeCards.map(\.isOpen) == [true, false, false, false])
    }

    @Test("reordenar mantiene abierta la card por ejercicio, no por índice")
    func reorder() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        await today.model.reorder(from: 0, to: 2)
        let cards = today.model.activeCards
        #expect(cards[2].title == "Press Banca")
        #expect(cards.map(\.isOpen) == [false, false, true])
    }
}

// tests/e2e/workout-subtitle-reps.spec.js
@MainActor
@Suite("Subtítulo de card muestra reps reales cuando difieren")
struct WorkoutSubtitleTests {
    private func started() async -> TodayHarness {
        let today = await TodayHarness.make()
        await today.start()
        return today
    }

    @Test("subtítulo muestra reps reales al iniciar si difieren del historial previo")
    func pressReps() async {
        #expect(await started().model.activeCards[0].subtitle.contains("10-10-8"))
    }

    @Test("subtítulo muestra reps de curl_biceps al iniciar si difieren")
    func curlReps() async {
        #expect(await started().model.activeCards[1].subtitle.contains("12-12-10"))
    }

    @Test("subtítulo NO muestra reps cuando todas coinciden con expected")
    func allMatch() async {
        let today = await started()
        today.model.focusSeries(2, at: 0)
        await today.model.chooseRep(10, series: 2, at: 0)
        let subtitle = today.model.activeCards[0].subtitle
        #expect(subtitle.contains("3×10"))
        #expect(!subtitle.contains("10-10"))
    }

    @Test("subtítulo se actualiza al cambiar una rep")
    func changeRep() async {
        let today = await started()
        today.model.focusSeries(2, at: 0)
        await today.model.chooseRep(7, series: 2, at: 0)
        #expect(today.model.activeCards[0].subtitle.contains("10-10-7"))
    }

    @Test("subtítulo se actualiza tras ajustar peso")
    func weight() async {
        let today = await started()
        let initial = today.model.activeCards[0].weight
        await today.model.adjust(.weight, direction: 1, at: 0)
        let subtitle = today.model.activeCards[0].subtitle
        #expect(subtitle.contains("\(LogText.kilograms(initial + ExerciseLog.weightStep(for: initial))) kg"))
        #expect(subtitle.contains("10-10-8"))
    }

    @Test("subtítulo incluye peso y series x reps esperadas junto a las reales")
    func full() async {
        let subtitle = await started().model.activeCards[0].subtitle
        #expect(subtitle.contains("60 kg"))
        #expect(subtitle.contains("3×10"))
        #expect(subtitle.contains("10-10-8"))
    }

    @Test("reps desaparecen del subtítulo si se corrigen para coincidir con expected")
    func fixed() async {
        let today = await started()
        await today.model.chooseRep(10, series: 2, at: 0)
        let subtitle = today.model.activeCards[0].subtitle
        #expect(subtitle.contains("3×10"))
        #expect(!subtitle.contains("10-10"))
    }
}

// tests/e2e/workout-reorder.spec.js. `GymCompanion.reorderExercises` es `reorder(from:to:)`.
@MainActor
@Suite("drag-reorder workout exercises")
struct WorkoutReorderTests {
    private func started() async -> TodayHarness {
        let today = await TodayHarness.make()
        await today.start()
        return today
    }

    /// `assertDomMatchesData`: cada tarjeta enseña el log que hay en su posición.
    private func expectCardsMatchData(_ today: TodayHarness) async {
        let logs = await today.savedToday?.logs ?? []
        #expect(today.model.activeCards.map(\.exerciseID) == logs.map(\.exerciseID))
        #expect(today.model.activeCards.map(\.weight) == logs.map(\.weight))
    }

    @Test("el handle (≡) es visible en cada tarjeta de ejercicio durante entreno activo")
    func handles() async {
        let today = await started()
        #expect(today.model.canReorder)
        #expect(!today.model.activeCards.isEmpty)
    }

    @Test("el handle NO aparece cuando no hay entreno activo (vista previa de hoy)")
    func noHandlesInPreview() async {
        let today = await TodayHarness.make()
        #expect(!today.model.canReorder)
        today.model.select("DIA1")
        #expect(!today.model.canReorder)
    }

    @Test("reorderExercises actualiza DB.routines en localStorage")
    func routine() async {
        let today = await started()
        await today.model.reorder(from: 0, to: 1)
        // Sin aviso: la tarjeta ya se ve en su sitio (quitado con la aprobación del usuario, 2026-10-26).
        #expect(today.app.notice == nil)
        #expect(await today.saved?.routines[0].exerciseIDs.prefix(2) == ["curl_biceps", "press_banca"])
    }

    @Test("reorderExercises actualiza entry.logs del entreno activo (invariante)")
    func logs() async {
        let today = await started()
        await today.model.reorder(from: 0, to: 1)
        #expect(await today.savedToday?.logs.prefix(2).map(\.exerciseID) == ["curl_biceps", "press_banca"])
    }

    @Test("tras reordenar y re-renderizar, el nuevo orden se refleja en el DOM")
    func afterTabSwitch() async {
        let today = await started()
        await today.model.reorder(from: 0, to: 1)
        today.model.reselect()
        #expect(today.model.stage == .active)
        #expect(today.model.activeCards.prefix(2).map(\.title) == ["Curl Bíceps", "Press Banca"])
    }

    @Test("editar peso tras reordenar modifica el ejercicio mostrado, no el que estaba antes en esa posición")
    func editWeightAfterReorder() async throws {
        let today = await started()
        let before = try #require(await today.savedToday?.logs)
        await today.model.reorder(from: 0, to: 2)
        #expect(today.model.activeCards[0].title == "Curl Bíceps")
        #expect(today.model.activeCards[2].title == "Press Banca")
        await expectCardsMatchData(today)
        await today.model.set(.weight, text: "88", at: 0)
        let after = try #require(await today.savedToday?.logs)
        #expect(after.first { $0.exerciseID == "curl_biceps" }?.weight == 88)
        #expect(after.first { $0.exerciseID == "press_banca" }?.weight == before.first { $0.exerciseID == "press_banca" }?.weight)
        #expect(after.first { $0.exerciseID == "ejercicio_sin_historial" }?.weight == before.first { $0.exerciseID == "ejercicio_sin_historial" }?.weight)
        await expectCardsMatchData(today)
    }

    @Test("editar reps por serie (chip) tras reordenar afecta al ejercicio correcto")
    func editRepAfterReorder() async throws {
        let today = await started()
        let before = try #require(await today.savedToday?.logs)
        await today.model.reorder(from: 0, to: 2)
        today.model.toggleCard(today.model.activeCards[0].exerciseID)
        today.model.focusSeries(0, at: 0)
        let chip = try #require(today.model.activeCards[0].chips.last)
        await today.model.chooseRep(chip.value, series: 0, at: 0)
        let after = try #require(await today.savedToday?.logs)
        #expect(after.first { $0.exerciseID == "curl_biceps" }?.actualReps[0] == chip.value)
        for id: ExerciseID in ["press_banca", "ejercicio_sin_historial"] {
            #expect(after.first { $0.exerciseID == id }?.actualReps == before.first { $0.exerciseID == id }?.actualReps)
        }
        await expectCardsMatchData(today)
    }

    @Test("ajustar peso con botones +/- tras reordenar afecta al ejercicio correcto")
    func adjustAfterReorder() async throws {
        let today = await started()
        let before = try #require(await today.savedToday?.logs)
        await today.model.reorder(from: 2, to: 0)
        await expectCardsMatchData(today)
        await today.model.adjust(.weight, direction: 1, at: 0)
        let after = try #require(await today.savedToday?.logs)
        let sinHistorial = try #require(before.first { $0.exerciseID == "ejercicio_sin_historial" }?.weight)
        #expect(after.first { $0.exerciseID == "ejercicio_sin_historial" }?.weight == sinHistorial + 1)
        #expect(after.first { $0.exerciseID == "press_banca" }?.weight == before.first { $0.exerciseID == "press_banca" }?.weight)
        #expect(after.first { $0.exerciseID == "curl_biceps" }?.weight == before.first { $0.exerciseID == "curl_biceps" }?.weight)
        await expectCardsMatchData(today)
    }

    @Test("varios reordenamientos consecutivos mantienen el DOM coherente y editar sigue siendo correcto")
    func chain() async throws {
        let today = await started()
        await today.model.reorder(from: 0, to: 2)
        await expectCardsMatchData(today)
        await today.model.reorder(from: 2, to: 1)
        await expectCardsMatchData(today)
        await today.model.reorder(from: 1, to: 0)
        await expectCardsMatchData(today)
        let logs = try #require(await today.savedToday?.logs)
        let first = logs[0].exerciseID
        await today.model.set(.weight, text: "77", at: 0)
        let after = try #require(await today.savedToday?.logs)
        #expect(after.first { $0.exerciseID == first }?.weight == 77)
        for log in after where log.exerciseID != first {
            #expect(log.weight == logs.first { $0.exerciseID == log.exerciseID }?.weight)
        }
        await expectCardsMatchData(today)
    }

    @Test("cambiar (swap) un ejercicio tras reordenar mantiene la correspondencia card↔log")
    func swapAfterReorder() async throws {
        let today = await started()
        await today.model.reorder(from: 0, to: 2)
        today.model.openSwapPicker(at: 0)
        await today.model.choose("sentadilla")
        // Sin aviso: la tarjeta ya se ve cambiada (quitado con la aprobación del usuario, 2026-10-26).
        #expect(today.app.notice == nil)
        let logs = try #require(await today.savedToday?.logs)
        #expect(logs[0].exerciseID == "sentadilla")
        #expect(!logs.contains { $0.exerciseID == "curl_biceps" })
        await expectCardsMatchData(today)
    }

    @Test("escenario reportado: añadir ejercicio mid-workout, moverlo y editarlo modifica el ejercicio correcto")
    func addMoveEdit() async throws {
        let today = await started()
        today.model.openAddPicker()
        await today.model.choose("sentadilla")
        // Sin aviso: la tarjeta nueva ya se ve (quitado con la aprobación del usuario, 2026-10-26).
        #expect(today.app.notice == nil)
        let logs = try #require(await today.savedToday?.logs)
        #expect(logs.last?.exerciseID == "sentadilla")
        await today.model.reorder(from: logs.count - 1, to: 0)
        #expect(today.model.activeCards[0].title == "Sentadilla")
        await expectCardsMatchData(today)
        await today.model.set(.weight, text: "130", at: 0)
        let after = try #require(await today.savedToday?.logs)
        #expect(after.first { $0.exerciseID == "sentadilla" }?.weight == 130)
        for id: ExerciseID in ["press_banca", "curl_biceps", "ejercicio_sin_historial"] {
            #expect(after.first { $0.exerciseID == id }?.weight == logs.first { $0.exerciseID == id }?.weight)
        }
    }

    @Test("el acordeón sigue funcionando tras reordenar y re-renderizar")
    func accordionAfterReorder() async {
        let today = await started()
        await today.model.reorder(from: 0, to: 1)
        today.model.reselect()
        today.model.toggleCard(today.model.activeCards[0].exerciseID)
        #expect(today.model.activeCards.map(\.isOpen).prefix(2) == [true, false])
        today.model.toggleCard(today.model.activeCards[1].exerciseID)
        #expect(today.model.activeCards.map(\.isOpen).prefix(2) == [false, true])
    }

    @Test("el ejercicio que estaba abierto sigue abierto tras reordenar, aunque cambie de posición")
    func openFollowsExercise() async {
        let today = await started()
        today.model.toggleCard("curl_biceps")
        await today.model.reorder(from: 1, to: 0)
        let open = today.model.activeCards.filter(\.isOpen)
        #expect(open.map(\.title) == ["Curl Bíceps"])
    }

    @Test("ejercicio añadido mid-workout también tiene drag-handle")
    func addedIsDraggable() async throws {
        let today = await started()
        let before = today.model.activeCards.count
        today.model.openAddPicker()
        let first = try #require(today.model.picker?.exercises.first)
        await today.model.choose(first.id)
        #expect(today.model.activeCards.count == before + 1)
        #expect(today.model.canReorder)
    }

    // Arrastrar no abre ni cierra tarjetas.
    @Test("clic en drag-handle no abre el acordeón")
    func dragDoesNotOpen() async {
        let today = await started()
        await today.model.reorder(from: 0, to: 1)
        #expect(today.model.activeCards.allSatisfy { !$0.isOpen })
    }
}

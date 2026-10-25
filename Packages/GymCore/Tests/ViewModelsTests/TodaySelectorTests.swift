import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// Port por comportamiento de los e2e del selector, la vista previa, la gestión de la rutina, el
// arranque y la precarga (Hoy). Mismo `describe` y nombre que en la PWA.

// tests/e2e/day-selector.spec.js
@MainActor
@Suite("Selector de rutinas (Hoy)")
struct DaySelectorTests {
    @Test("muestra 3 botones de día en la vista inicial")
    func threeDays() async {
        let today = await TodayHarness.make()
        #expect(today.model.stage == .selector)
        #expect(today.model.title == "Rutinas")
        #expect(today.model.routineRows.map(\.title) == ["Full Body - Día 1", "Full Body - Día 2", "Full Body - Día 3"])
    }

    @Test("seleccionar DIA2 muestra preview con ejercicios de DIA2")
    func previewDia2() async {
        let today = await TodayHarness.make()
        today.model.select("DIA2")
        #expect(today.model.previewCards.map(\.title) == ["Sentadilla"])
    }

    @Test("seleccionar DIA3 muestra preview con ejercicios de DIA3")
    func previewDia3() async {
        let today = await TodayHarness.make()
        today.model.select("DIA3")
        #expect(today.model.previewCards.map(\.title) == ["Press Banca", "Sentadilla"])
    }

    @Test("botón Volver desde DIA2 regresa al selector")
    func back() async {
        let today = await TodayHarness.make()
        today.model.select("DIA2")
        #expect(today.model.stage == .preview("DIA2"))
        today.model.backToSelector()
        #expect(today.model.stage == .selector)
        #expect(today.model.routineRows.count == 3)
        #expect(today.model.previewCards.isEmpty)
    }

    @Test("iniciar desde DIA2 crea entry con type DIA2 en DB")
    func startDia2() async {
        let today = await TodayHarness.make()
        await today.start("DIA2")
        #expect(today.model.stage == .active)
        #expect(today.model.activeStatus == "Entreno en curso — Full Body - Día 2")
        #expect(await today.savedToday?.routineID == "DIA2")
    }

    @Test("entreno iniciado desde DIA2 muestra ejercicios de DIA2")
    func activeDia2() async {
        let today = await TodayHarness.make()
        await today.start("DIA2")
        #expect(today.model.activeCards.map(\.title) == ["Sentadilla"])
    }
}

@MainActor
@Suite("Selector de rutinas: resumen de cada rutina")
struct RoutineRowTests {
    @Test("cada rutina dice cuántos ejercicios tiene y los tres primeros")
    func summary() async {
        let today = await TodayHarness.make()
        #expect(today.model.routineRows[0].subtitle == "3 ejercicios · Press Banca, Curl Bíceps, Ejercicio Sin Historial")
        var data = PWATestDB.data
        data.routines[0].exerciseIDs.append("sentadilla")
        let longer = await TodayHarness.make(data)
        #expect(longer.model.routineRows[0].subtitle == "4 ejercicios · Press Banca, Curl Bíceps, Ejercicio Sin Historial...")
    }

    @Test("el título de la vista previa es el de la rutina")
    func previewTitle() async {
        let today = await TodayHarness.make()
        today.model.select("DIA1")
        #expect(today.model.title == "Rutina de Full Body - Día 1")
    }
}

// tests/e2e/routine-preview-accordion.spec.js
@MainActor
@Suite("Rutina preview — cards expandibles (solo lectura)")
struct RoutinePreviewTests {
    private func preview(_ routine: RoutineID = "DIA1") async -> TodayHarness {
        let today = await TodayHarness.make()
        today.model.select(routine)
        return today
    }

    @Test("todas las cards empiezan colapsadas")
    func collapsed() async {
        let today = await preview()
        #expect(today.model.previewCards.allSatisfy { !$0.isOpen })
    }

    @Test("hay una card por ejercicio de la rutina")
    func onePerExercise() async {
        #expect(await preview().model.previewCards.count == 3)
    }

    @Test("las cards muestran nombre y subtitle antes de expandir")
    func nameAndSubtitle() async {
        let card = await preview().model.previewCards[0]
        #expect(card.title == "Press Banca")
        #expect(!card.subtitle.isEmpty)
    }

    @Test("clicar header expande la card")
    func expand() async {
        let today = await preview()
        today.model.togglePreviewCard(0)
        #expect(today.model.previewCards[0].isOpen)
    }

    // El chevron de la vista sigue a `isOpen`: no hay otro estado que sincronizar.
    @Test("el chevron se sincroniza al expandir")
    func chevron() async {
        let today = await preview()
        today.model.togglePreviewCard(0)
        #expect(today.model.openPreviewCards == [0])
    }

    @Test("clicar una card expandida la colapsa")
    func collapse() async {
        let today = await preview()
        today.model.togglePreviewCard(0)
        today.model.togglePreviewCard(0)
        #expect(!today.model.previewCards[0].isOpen)
    }

    @Test("las cards son independientes — varias pueden estar abiertas a la vez")
    func independent() async {
        let today = await preview()
        today.model.togglePreviewCard(0)
        today.model.togglePreviewCard(1)
        #expect(today.model.previewCards.filter(\.isOpen).count == 2)
    }

    @Test("cerrar una card no afecta a las demás")
    func closeOne() async {
        let today = await preview()
        today.model.togglePreviewCard(0)
        today.model.togglePreviewCard(1)
        today.model.togglePreviewCard(0)
        #expect(!today.model.previewCards[0].isOpen)
        #expect(today.model.previewCards[1].isOpen)
    }

    @Test("el body expandido no contiene inputs de texto ni número")
    func noInputs() async {
        #expect(await preview().model.previewCards.allSatisfy { !$0.isEditable })
    }

    @Test("los parámetros se muestran como .param-value (no como inputs)")
    func paramValues() async {
        let card = await preview().model.previewCards[0]
        #expect(!card.isEditable)
        #expect((card.weight, card.series, card.targetReps) == (60, 3, 10))
    }

    @Test("los botones +/- de parámetros no existen en modo lectura")
    func noButtons() async {
        #expect(await preview().model.previewCards.allSatisfy { !$0.isEditable && $0.chips.isEmpty })
    }

    @Test("las series se muestran como .series-cell-static (no como inputs)")
    func staticSeries() async {
        let card = await preview().model.previewCards[0]
        #expect(card.cells.count == 3)
        #expect(!card.isEditable)
    }

    @Test("los param-value muestran los valores del último entreno (press_banca)")
    func pressValues() async {
        let card = await preview().model.previewCards[0]
        #expect(LogText.kilograms(card.weight) == "60")
        #expect(card.series == 3)
        #expect(card.targetReps == 10)
    }

    @Test("las series-cell-static muestran las reps reales del último entreno")
    func pressReps() async {
        #expect(await preview().model.previewCards[0].cells.map(\.text) == ["10", "10", "8"])
    }

    @Test("los labels de serie son S1, S2, S3...")
    func labels() async {
        #expect(await preview().model.previewCards[0].cells.map(\.label) == ["S1", "S2", "S3"])
    }

    @Test("second exercise shows correct param values (curl_biceps)")
    func curlValues() async {
        let card = await preview().model.previewCards[1]
        #expect((card.weight, card.series, card.targetReps) == (15, 3, 12))
    }

    @Test("second exercise shows correct series values (curl_biceps)")
    func curlReps() async {
        #expect(await preview().model.previewCards[1].cells.map(\.text) == ["12", "12", "10"])
    }

    @Test("series con val >= expected tienen clase done (verde)")
    func done() async {
        let cells = await preview().model.previewCards[0].cells
        #expect(cells[0].state == .done)
        #expect(cells[1].state == .done)
    }

    @Test("series con val < expected tienen clase filled (azul)")
    func filled() async {
        #expect(await preview().model.previewCards[0].cells[2].state == .filled)
    }

    @Test("series sin valor no tienen clase done ni filled")
    func empty() async {
        let cells = await preview().model.previewCards[2].cells
        #expect(!cells.isEmpty)
        #expect(cells.allSatisfy { $0.state == .empty })
    }

    @Test("ejercicio sin historial de reps muestra — en las series")
    func dash() async {
        let cells = await preview().model.previewCards[2].cells
        #expect(!cells.isEmpty)
        #expect(cells.allSatisfy { $0.text == "—" })
    }

    @Test("la sección de series tiene label \"Reps por serie\"")
    func seriesLabel() {
        #expect(TodayText.seriesSectionLabel == "Reps por serie")
    }

    @Test("la sección de params tiene los labels correctos")
    func paramLabels() {
        #expect([TodayText.weightLabel, TodayText.seriesLabel, TodayText.targetRepsLabel] == ["Peso (kg)", "Series", "Reps obj."])
    }

    @Test("no hay botón Guardar en ninguna card de rutina preview")
    func noSave() async {
        let today = await preview()
        for index in today.model.previewCards.indices { today.model.togglePreviewCard(index) }
        #expect(today.model.previewCards.allSatisfy { $0.isOpen && !$0.isEditable })
    }

    @Test("volver al selector y re-entrar resetea el estado (todas cerradas)")
    func reset() async {
        let today = await preview()
        today.model.togglePreviewCard(0)
        today.model.backToSelector()
        today.model.select("DIA1")
        #expect(today.model.previewCards.allSatisfy { !$0.isOpen })
    }

    @Test("iniciar entreno funciona correctamente después de expandir cards")
    func startAfterExpanding() async {
        let today = await preview()
        today.model.togglePreviewCard(0)
        await today.model.start()
        #expect(today.model.stage == .active)
    }

    @Test("DIA2 muestra sus propios ejercicios con valores correctos")
    func dia2() async {
        let cards = await preview("DIA2").model.previewCards
        #expect(cards.map(\.title) == ["Sentadilla"])
        #expect(cards[0].weight == 100)
        #expect(cards[0].series == 3)
    }

    @Test("el historial strip se muestra para ejercicios con historial")
    func strip() async {
        #expect(await preview().model.previewCards[0].strip != nil)
    }
}

// tests/e2e/routine.spec.js
@MainActor
@Suite("Gestion de rutina")
struct RoutineManagementTests {
    @Test("añadir ejercicio existente a rutina se guarda en DB")
    func addExisting() async throws {
        let today = await TodayHarness.make()
        await today.start()
        let before = try #require(await today.saved?.routines[0].exerciseIDs.count)
        today.model.openAddPicker()
        let first = try #require(today.model.picker?.exercises.first)
        await today.model.choose(first.id)
        #expect(await today.saved?.routines[0].exerciseIDs.count == before + 1)
    }

    @Test("crear ejercicio nuevo se guarda en DB y rutina")
    func create() async throws {
        let today = await TodayHarness.make()
        await today.start()
        let before = try #require(await today.saved?.routines[0].exerciseIDs.count)
        today.model.openAddPicker()
        today.model.isCreatePresented = true
        today.model.createName = "Press Arnold"
        await today.model.createExercise()
        let saved = try #require(await today.saved)
        #expect(saved.routines[0].exerciseIDs.count == before + 1)
        #expect(saved.catalog["press_arnold"] != nil)
    }

    @Test("crear ejercicio con nombre duplicado muestra warning y modal sigue abierto")
    func duplicate() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.openAddPicker()
        today.model.isCreatePresented = true
        today.model.createName = "Press Banca"
        await today.model.createExercise()
        #expect(today.app.notice?.text.contains("Ya existe") == true)
        #expect(today.model.isCreatePresented)
        #expect(today.model.createName == "Press Banca")
    }

    @Test("crear ejercicio nuevo cierra el modal tras éxito")
    func createCloses() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.openAddPicker()
        today.model.isCreatePresented = true
        today.model.createName = "Ejercicio Único XYZ"
        await today.model.createExercise()
        #expect(!today.model.isCreatePresented)
        #expect(today.model.picker == nil)
    }

    @Test("buscar ejercicio en modal filtra correctamente")
    func search() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.openAddPicker()
        today.model.pickerQuery = "sentad"
        #expect((today.model.picker?.exercises.count ?? 0) >= 1)
        #expect(today.model.picker?.exercises.allSatisfy { $0.name.searchFolded.contains("sentad") } == true)
    }

    @Test("añadir ejercicio durante entreno activo aparece como card")
    func addCard() async throws {
        let today = await TodayHarness.make()
        await today.start()
        let before = today.model.activeCards.count
        today.model.openAddPicker()
        let first = try #require(today.model.picker?.exercises.first)
        await today.model.choose(first.id)
        #expect(today.model.activeCards.count == before + 1)
    }

    @Test("crear ejercicio nuevo a mitad de entreno aparece como card y en logs")
    func createMidWorkout() async throws {
        let today = await TodayHarness.make()
        await today.start()
        let before = today.model.activeCards.count
        today.model.openAddPicker()
        today.model.isCreatePresented = true
        today.model.createName = "Ejercicio Mid Entreno"
        await today.model.createExercise()
        #expect(today.model.activeCards.count == before + 1)
        let saved = try #require(await today.saved)
        #expect(saved.routines[0].exerciseIDs.contains("ejercicio_mid_entreno"))
        #expect(saved.catalog["ejercicio_mid_entreno"] != nil)
        let last = try #require(saved.history.session(on: today.today)?.logs.last)
        #expect(last.exerciseID == "ejercicio_mid_entreno")
        #expect(last.actualReps.allSatisfy { $0 != nil })
    }

    @Test("crear ejercicio nuevo a mitad de entreno NO desaparece de la lista al re-abrir")
    func createdIsCard() async {
        let today = await TodayHarness.make()
        await today.start()
        today.model.openAddPicker()
        today.model.isCreatePresented = true
        today.model.createName = "Hammer Curl Unicornio"
        await today.model.createExercise()
        #expect(today.model.activeCards.contains { $0.title == "Hammer Curl Unicornio" })
    }
}

// tests/e2e/session.spec.js: el arranque sin sistema de sesiones.
@MainActor
@Suite("Arranque sin sistema de sesiones")
struct StartupTests {
    @Test("con DB en localStorage → app arranca directamente")
    func withData() async {
        let today = await TodayHarness.make()
        #expect(today.app.data == PWATestDB.data)
        #expect(today.model.stage == .selector)
    }

    // La app no lleva un db.json dentro (decisión de #6): sin datos arranca con las tres rutinas
    // vacías, que es lo que la PWA hacía si tampoco tenía su db.json.
    @Test("sin DB en localStorage → arranca con db.json por defecto")
    func withoutData() async {
        let harness = SyncHarness(local: nil, configured: false)
        let app = AppModel(repository: harness.repository())
        await app.start()
        #expect(app.data == TrainingData())
        #expect(app.loadError == nil)
    }

    // No hay datos de sesión que ignorar: la app nunca tuvo login. Lo que queda es que unos datos
    // con solo lo mínimo (sin historial) arrancan bien.
    @Test("gym_companion_session ignorado si existe (dato legado)")
    func legacySession() async {
        let data = TrainingData(catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca")]),
                                routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca"])])
        let today = await TodayHarness.make(data)
        #expect(today.app.data == data)
        #expect(today.model.routineRows.count == 1)
    }

    @Test("no hay botón de logout ni pantalla de login")
    func noLogin() async {
        // La app no tiene ningún modelo de acceso: arranca directamente en Rutinas.
        let today = await TodayHarness.make()
        #expect(today.model.title == "Rutinas")
    }
}

// tests/e2e/best-recent-preload.spec.js
@MainActor
@Suite("Precarga \"mejor de las últimas 4\" al iniciar entreno")
struct BestRecentPreloadTests {
    /// Dos sesiones de DIA1: la antigua con más volumen y la reciente con menos.
    private func data() -> TrainingData {
        let today = SyncFixtures.today
        return TrainingData(
            catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca"), Exercise(id: "curl_biceps", name: "Curl Bíceps")]),
            routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca"]),
                       Routine(id: "DIA2", name: "Full Body - Día 2"), Routine(id: "DIA3", name: "Full Body - Día 3")],
            history: [
                Session(date: today.adding(days: -30), routineID: "DIA1", completed: true, logs: [
                    ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 12, actualReps: [12, 12, 12], weight: 50),
                    ExerciseLog(exerciseID: "curl_biceps", series: 3, targetReps: 10, actualReps: [10, 10, 10], weight: 20),
                ]),
                Session(date: today.adding(days: -7), routineID: "DIA1", completed: true, logs: [
                    ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 12, actualReps: [10, 10, 10], weight: 50),
                    ExerciseLog(exerciseID: "curl_biceps", series: 3, targetReps: 10, actualReps: [8, 8, 8], weight: 12),
                ]),
            ]
        )
    }

    @Test("iniciar DIA1 precarga los valores de la sesión con mayor volumen, no los de la más reciente")
    func start() async throws {
        let today = await TodayHarness.make(data())
        await today.start()
        let log = try #require(await today.savedToday?.logs.first { $0.exerciseID == "press_banca" })
        #expect(log.weight == 50)
        #expect(log.series == 3)
        #expect(log.targetReps == 12)
        #expect(log.actualReps == [12, 12, 12])
    }

    @Test("añadir ejercicio mid-entreno precarga los valores de la sesión con mayor volumen (no los de la más reciente)")
    func addMidWorkout() async throws {
        let today = await TodayHarness.make(data())
        await today.start()
        today.model.openAddPicker()
        await today.model.choose("curl_biceps")
        let log = try #require(await today.savedToday?.logs.first { $0.exerciseID == "curl_biceps" })
        #expect(log.weight == 20)
        #expect(log.actualReps == [10, 10, 10])
    }
}

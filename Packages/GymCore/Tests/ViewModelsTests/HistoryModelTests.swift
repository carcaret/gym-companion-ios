import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

/// Historial con el `db-test.json` de los e2e (o los datos que se pasen), sin GitHub.
@MainActor
struct HistoryHarness {
    let harness: SyncHarness
    let app: AppModel
    let navigation: NavigationModel
    let model: HistoryModel

    static func make(_ data: TrainingData = PWATestDB.data) async -> HistoryHarness {
        let harness = SyncHarness(local: data, configured: false)
        let app = AppModel(repository: harness.repository())
        await app.start()
        let navigation = NavigationModel()
        navigation.select(.history)
        return HistoryHarness(harness: harness, app: app, navigation: navigation,
                              model: HistoryModel(app: app, navigation: navigation, clock: FixedClock(SyncFixtures.today)))
    }

    var saved: TrainingData? {
        get async { await harness.savedLocally }
    }

    /// Abre la primera sesión de la lista (la más reciente) y su primera tarjeta.
    func openFirstAndExpand() {
        model.open(model.rows[0].date)
        model.toggleCard(0)
    }
}

// tests/e2e/history-full.spec.js. La primera sesión de la lista es la del 2024-01-10 (Sentadilla).
@MainActor
@Suite("Historial completo")
struct HistoryFullTests {
    @Test("click en entry muestra detalle con ejercicios")
    func detail() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows[0].date)
        #expect(!history.model.cards.isEmpty)
    }

    @Test("detalle muestra peso, series, reps por ejercicio")
    func summary() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows[0].date)
        let subtitle = history.model.cards[0].subtitle
        #expect(subtitle.contains("kg"))
        #expect(subtitle.contains("3×8"))
    }

    @Test("tap en card expande y muestra controles de edicion")
    func expand() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        #expect(history.model.cards[0].isOpen)
        #expect(history.model.cards[0].isEditable)
    }

    @Test("segundo tap en card colapsa el body")
    func collapse() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.toggleCard(0)
        #expect(history.model.cards.allSatisfy { !$0.isOpen })
    }

    @Test("boton Guardar no aparece antes de modificar nada")
    func noSaveYet() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        #expect(!history.model.cards[0].isDirty)
    }

    @Test("boton Guardar aparece al modificar un valor")
    func saveAppears() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.set(.weight, text: "75", at: 0)
        #expect(history.model.cards[0].isDirty)
    }

    @Test("guardar actualiza subtitulo y colapsa la card")
    func save() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.set(.weight, text: "75", at: 0)
        await history.model.save(0)
        #expect(history.model.cards.allSatisfy { !$0.isOpen })
        #expect(history.model.cards[0].subtitle.contains("75"))
    }

    @Test("colapsar sin guardar descarta cambios y muestra valor original al reexpandir")
    func discardOnCollapse() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        let original = history.model.cards[0].weight
        history.model.set(.weight, text: "999", at: 0)
        #expect(history.model.cards[0].isDirty)
        history.model.toggleCard(0)
        #expect(history.model.cards.allSatisfy { !$0.isOpen })
        history.model.toggleCard(0)
        #expect(history.model.cards[0].weight == original)
    }

    @Test("navegar atras sin guardar descarta cambios")
    func discardOnBack() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        let original = history.model.cards[0].weight
        history.model.set(.weight, text: "999", at: 0)
        history.model.back()
        #expect(history.model.selectedDate == nil)
        history.openFirstAndExpand()
        #expect(history.model.cards[0].weight == original)
    }

    @Test("eliminar entry confirmar desaparece de la lista")
    func delete() async {
        let history = await HistoryHarness.make()
        let initial = history.model.rows.count
        history.model.requestDelete(history.model.rows[0].date)
        #expect(history.model.deletePrompt?.title.contains("Borrar") == true)
        await history.model.confirmDelete()
        #expect(history.model.rows.count == initial - 1)
        #expect(await history.saved?.history.count == initial - 1)
    }

    @Test("eliminar entry cancelar sigue en la lista")
    func cancelDelete() async {
        let history = await HistoryHarness.make()
        let initial = history.model.rows.count
        history.model.requestDelete(history.model.rows[0].date)
        history.model.cancelDelete()
        #expect(history.model.rows.count == initial)
    }

    @Test("volver desde detalle vuelve a la lista")
    func back() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows[0].date)
        history.model.back()
        #expect(history.model.selectedDate == nil)
        #expect(!history.model.rows.isEmpty)
    }

    @Test("navegar a entry A → volver → entry B no muestra datos de A")
    func noLeak() async {
        let history = await HistoryHarness.make()
        #expect(history.model.rows.count == 3)
        history.model.open(history.model.rows[0].date)
        #expect(history.model.cards.map(\.title) == ["Sentadilla"])
        history.model.back()
        history.model.open(history.model.rows[1].date)
        #expect(history.model.cards.map(\.title) == ["Press Banca", "Curl Bíceps"])
    }

    @Test("subtitulo se actualiza al modificar peso sin guardar")
    func liveSubtitle() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        let before = history.model.cards[0].subtitle
        history.model.set(.weight, text: "123", at: 0)
        let after = history.model.cards[0].subtitle
        #expect(after.contains("123"))
        #expect(after != before)
    }

    @Test("boton + de peso actualiza el input de peso")
    func plusWeight() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        let initial = history.model.cards[0].weight
        history.model.adjust(.weight, direction: 1, at: 0)
        #expect(history.model.cards[0].weight == initial + 5)
    }

    @Test("boton - de peso actualiza el input de peso")
    func minusWeight() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        let initial = history.model.cards[0].weight
        history.model.adjust(.weight, direction: -1, at: 0)
        #expect(history.model.cards[0].weight == max(0, initial - 5))
    }

    @Test("boton + de series actualiza el input de series")
    func plusSeries() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        let initial = history.model.cards[0].series
        history.model.adjust(.series, direction: 1, at: 0)
        #expect(history.model.cards[0].series == initial + 1)
    }

    @Test("chip de serie en historial abre chip strip y permite cambiar rep")
    func chips() async throws {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.focusSeries(0, at: 0)
        let chip = try #require(history.model.cards[0].chips.first)
        history.model.chooseRep(chip.value, series: 0, at: 0)
        #expect(history.model.cards[0].cells[0].text == "\(chip.value)")
        #expect(history.model.cards[0].isDirty)
    }
}

@MainActor
@Suite("Historial: lista")
struct HistoryListTests {
    @Test("de la más reciente a la más antigua, con rutina, fecha y resumen")
    func rows() async {
        let history = await HistoryHarness.make()
        let rows = history.model.rows
        #expect(rows.map(\.date.iso) == ["2024-01-10", "2024-01-08", "2024-01-05"])
        #expect(rows[1].routine == "Full Body - Día 1")
        #expect(rows[1].day == "8")
        #expect(rows[1].month == "ENE")
        #expect(rows[1].summary == "2 ejercicios · Press Banca · Curl Bíceps")
    }

    @Test("cada sesión lleva el color de su rutina (filete y etiqueta de la PWA)")
    func tint() async {
        let history = await HistoryHarness.make()
        #expect(history.model.rows[1].tint == .day1)
    }

    @Test("sin sesiones, la lista está vacía (y la vista dice que no hay)")
    func empty() async {
        let history = await HistoryHarness.make(TrainingData())
        #expect(history.model.rows.isEmpty)
        #expect(HistoryText.empty == "No hay sesiones registradas")
    }

    @Test("el resumen de una sesión larga dice cuántos ejercicios más hay")
    func longSummary() {
        #expect(HistoryText.sessionSummary(["A", "B", "C", "D", "E"]) == "5 ejercicios · A · B · C +2")
    }

    @Test("el título del detalle es la rutina y la fecha larga")
    func detailTitle() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows[1].date)
        #expect(history.model.detailTitle == "Full Body - Día 1 — lun, 8 ene 2024")
    }

    @Test("volver a la pestaña enseña la lista")
    func appear() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows[0].date)
        history.model.appear()
        #expect(history.model.selectedDate == nil)
    }
}

// tests/e2e/history-incomplete.spec.js
@MainActor
@Suite("Historial — entrenos incompletos")
struct HistoryIncompleteTests {
    private static let incompleteDate = LocalDate(iso: "2026-04-24")!
    private static let completeDate = LocalDate(iso: "2026-04-23")!

    private func make() async -> HistoryHarness {
        await HistoryHarness.make(TrainingData(
            catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca"), Exercise(id: "curl_biceps", name: "Curl Bíceps")]),
            routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl_biceps"]),
                       Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["press_banca"]),
                       Routine(id: "DIA3", name: "Full Body - Día 3", exerciseIDs: ["curl_biceps"])],
            history: [
                Session(date: Self.incompleteDate, routineID: "DIA1", completed: false, logs: [
                    ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [nil, nil, nil], weight: 60),
                ]),
                Session(date: Self.completeDate, routineID: "DIA2", completed: true, logs: [
                    ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 10, 10], weight: 65),
                ]),
            ]
        ))
    }

    private func row(_ history: HistoryHarness, _ date: LocalDate) -> HistoryModel.Row? {
        history.model.rows.first { $0.date == date }
    }

    @Test("card incompleta: tiene fondo y borde azulado")
    func incompleteTint() async {
        #expect(row(await make(), Self.incompleteDate)?.isIncomplete == true)
    }

    @Test("card incompleta: tiene icono de pausa en .day-info-top")
    func incompletePause() async {
        #expect(row(await make(), Self.incompleteDate)?.isIncomplete == true)
    }

    @Test("card completa: NO tiene tinte azulado")
    func completeNoTint() async {
        #expect(row(await make(), Self.completeDate)?.isIncomplete == false)
    }

    @Test("card completa: NO tiene icono de pausa en .day-info-top")
    func completeNoPause() async {
        #expect(row(await make(), Self.completeDate)?.isIncomplete == false)
    }

    @Test("detalle entreno incompleto: header muestra badge \"Incompleto\"")
    func incompleteBadge() async {
        let history = await make()
        history.model.open(Self.incompleteDate)
        #expect(history.model.isIncomplete)
        #expect(HistoryText.incomplete == "Incompleto")
    }

    @Test("detalle entreno completo: header NO muestra badge \"Incompleto\"")
    func completeNoBadge() async {
        let history = await make()
        history.model.open(Self.completeDate)
        #expect(!history.model.isIncomplete)
    }

    @Test("detalle entreno incompleto: muestra botón \"Completar entreno\"")
    func completeButton() async {
        let history = await make()
        history.model.open(Self.incompleteDate)
        #expect(history.model.isIncomplete)
        #expect(HistoryText.completeWorkout == "Completar entreno")
    }

    @Test("detalle entreno completo: NO muestra botón \"Completar entreno\"")
    func noCompleteButton() async {
        let history = await make()
        history.model.open(Self.completeDate)
        #expect(!history.model.isIncomplete)
    }

    @Test("detalle entreno completo: botones en view-nav-actions (solo Volver)")
    func onlyBack() async {
        let history = await make()
        history.model.open(Self.completeDate)
        #expect(!history.model.isIncomplete)
    }

    @Test("detalle entreno incompleto: botón Volver regresa a la lista")
    func back() async {
        let history = await make()
        history.model.open(Self.incompleteDate)
        history.model.back()
        #expect(history.model.selectedDate == nil)
    }

    @Test("botón \"Completar entreno\" navega al tab Hoy")
    func navigatesToToday() async {
        let history = await make()
        history.model.open(Self.incompleteDate)
        await history.model.completeWorkout()
        #expect(history.navigation.selectedTab == .routines)
    }

    @Test("botón \"Completar entreno\" marca el entreno como completado en DB")
    func marksCompleted() async {
        let history = await make()
        history.model.open(Self.incompleteDate)
        await history.model.completeWorkout()
        #expect(await history.saved?.history.session(on: Self.incompleteDate)?.completed == true)
    }

    @Test("tras completar, el entreno ya no aparece con tinte azul en historial")
    func noTintAfter() async {
        let history = await make()
        history.model.open(Self.incompleteDate)
        await history.model.completeWorkout()
        history.model.appear()
        #expect(history.model.rows.allSatisfy { !$0.isIncomplete })
    }

    @Test("badge \"Incompleto\" aparece debajo del título, no incrustado en él")
    func badgeSeparate() async {
        let history = await make()
        history.model.open(Self.incompleteDate)
        #expect(history.model.detailTitle.contains("—"))
        #expect(!history.model.detailTitle.contains("Incompleto"))
        #expect(history.model.isIncomplete)
    }
}

// tests/e2e/validation-history.spec.js
@MainActor
@Suite("Validación en edición de Historial")
struct HistoryValidationTests {
    @Test("expandir entry → todo correcto → guardar se cierra normalmente")
    func saveCloses() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.set(.weight, text: "\(Int(history.model.cards[0].weight) + 5)", at: 0)
        await history.model.save(0)
        #expect(history.model.cards.allSatisfy { !$0.isOpen })
    }

    @Test("entry con reps.actual vacío → al expandir se rellenan con expected")
    func prefill() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows.last!.date)
        history.model.toggleCard(0)
        #expect(history.model.cards[0].cells[0].text == "10")
    }

    @Test("entry con reps.actual vacío → colapsar sin guardar → reexpandir → sigue rellenando con expected")
    func prefillAgain() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows.last!.date)
        history.model.toggleCard(0)
        #expect(history.model.cards[0].cells[0].text == "10")
        history.model.toggleCard(0)
        history.model.toggleCard(0)
        #expect(history.model.cards[0].cells[0].text == "10")
    }

    @Test("guardar persiste cambio en localStorage")
    func persists() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.set(.weight, text: "77", at: 0)
        await history.model.save(0)
        #expect(history.model.cards.allSatisfy { !$0.isOpen })
        #expect(await history.saved?.history.session(on: LocalDate(iso: "2024-01-10")!)?.logs[0].weight == 77)
    }

    @Test("colapsar sin guardar NO persiste cambio en localStorage")
    func notPersisted() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        let original = history.model.cards[0].weight
        history.model.set(.weight, text: "999", at: 0)
        history.model.toggleCard(0)
        #expect(await history.saved?.history.session(on: LocalDate(iso: "2024-01-10")!)?.logs[0].weight == original)
    }
}

// tests/e2e/view-nav-buttons.spec.js, la parte del detalle del historial.
@MainActor
@Suite("Botones de navegación en vistas (Volver + Ejercicio)")
struct HistoryNavigationButtonsTests {
    @Test("history detail: botón Volver vuelve a la lista de historial")
    func back() async {
        let history = await HistoryHarness.make()
        history.model.open(history.model.rows[0].date)
        history.model.back()
        #expect(history.model.selectedDate == nil)
        #expect(!history.model.rows.isEmpty)
    }
}

/// Las sesiones de los e2e de la tira: hace 200, 14 y 7 días, todas de press banca en DIA1.
private func recentHistory() -> TrainingData {
    let today = SyncFixtures.today
    func session(_ daysAgo: Int, _ actual: [Int?], _ weight: Double) -> Session {
        Session(date: today.adding(days: -daysAgo), routineID: "DIA1", completed: true,
                logs: [ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: actual, weight: weight)])
    }
    return TrainingData(
        catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca"), Exercise(id: "curl_biceps", name: "Curl Bíceps"),
                          Exercise(id: "sentadilla", name: "Sentadilla")]),
        routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl_biceps"]),
                   Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["sentadilla"]),
                   Routine(id: "DIA3", name: "Full Body - Día 3", exerciseIDs: ["press_banca", "sentadilla"])],
        history: [session(200, [10, 10, 10], 50), session(14, [10, 10, 8], 55), session(7, [12, 11, 10], 60)]
    )
}

@MainActor
private func stripOfFirstCard(_ data: TrainingData) async throws -> (TodayHarness, HistoryStripContent) {
    let today = await TodayHarness.make(data)
    await today.start("DIA1")
    today.model.toggleCard("press_banca")
    return (today, try #require(today.model.activeCards[0].strip))
}

// tests/e2e/history-strip.spec.js
@MainActor
@Suite("History strip (franja de últimas sesiones)")
struct HistoryStripE2ETests {
    @Test("renderiza 6 columnas semanales en el card del ejercicio")
    func sixColumns() async throws {
        #expect(try await stripOfFirstCard(recentHistory()).1.bars.count == 6)
    }

    @Test("W-5/W-4/W-3 quedan vacías (no hay sesión) y W-2/W-1 con datos")
    func emptyAndFull() async throws {
        let bars = try await stripOfFirstCard(recentHistory()).1.bars
        #expect(bars.prefix(3).allSatisfy { $0.kind == .empty })
        #expect(bars[3].kind != .empty)
        #expect(bars[4].kind != .empty)
    }

    @Test("sesiones fuera de la ventana de 6 semanas no ocupan bucket W-5")
    func outsideWindow() async throws {
        #expect(try await stripOfFirstCard(recentHistory()).1.bars[0].kind == .empty)
    }

    @Test("tooltip en 2 líneas: \"e1RM Xkg\\n<peso>kg · <reps>\"")
    func tooltip() async throws {
        let bars = try await stripOfFirstCard(recentHistory()).1.bars
        guard case .session(_, _, _, let w1) = bars[4].kind, case .session(_, _, _, let w2) = bars[3].kind else {
            Issue.record("faltan barras")
            return
        }
        #expect(w1 == "e1RM 84kg\n60kg · 12-11-10")
        #expect(w1.split(separator: "\n").joined(separator: " · ") == "e1RM 84kg · 60kg · 12-11-10")
        #expect(w2 == "e1RM 73.3kg\n55kg · 10-10-8")
    }

    @Test("barra más alta corresponde a la sesión con mayor e1RM")
    func tallest() async throws {
        let bars = try await stripOfFirstCard(recentHistory()).1.bars
        guard case .session(let h1, _, _, _) = bars[4].kind, case .session(let h2, _, _, _) = bars[3].kind else {
            Issue.record("faltan barras")
            return
        }
        #expect(h1 > h2)
    }

    @Test("barras vacías no tienen atributo data-tooltip")
    func emptyNoTooltip() async throws {
        let bars = try await stripOfFirstCard(recentHistory()).1.bars
        #expect(bars.filter { $0.kind == .empty }.allSatisfy { $0.dateLabel.isEmpty })
    }

    @Test("el bucket W0 muestra la fecha de hoy durante entreno activo (precarga rellena actuals)")
    func today() async throws {
        let bar = try #require(try await stripOfFirstCard(recentHistory()).1.bars.last)
        #expect(bar.dateLabel == DateText.short(SyncFixtures.today))
        guard case .session(_, _, let isCurrent, _) = bar.kind else {
            Issue.record("la última no es una sesión")
            return
        }
        #expect(isCurrent)
    }
}

// tests/e2e/bar-colors.spec.js
@MainActor
@Suite("Colores de barras del history strip")
struct BarColorsE2ETests {
    private func data() -> TrainingData {
        let today = SyncFixtures.today
        return TrainingData(
            catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca")]),
            routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca"]),
                       Routine(id: "DIA2", name: "Full Body - Día 2"), Routine(id: "DIA3", name: "Full Body - Día 3")],
            history: [
                Session(date: today.adding(days: -14), routineID: "DIA1", completed: true,
                        logs: [ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 10, 8], weight: 60)]),
                Session(date: today.adding(days: -7), routineID: "DIA1", completed: true,
                        logs: [ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [12, 11, 10], weight: 60)]),
            ]
        )
    }

    private func color(_ bar: StripBar) -> RGB? {
        if case .session(_, let color, _, _) = bar.kind { return color }
        return nil
    }

    @Test("sesión cumplida → barra AZUL (B > G); sesión por debajo → barra VERDE (G > B)")
    func blueAndGreen() async throws {
        let bars = try await stripOfFirstCard(data()).1.bars
        let blue = try #require(color(bars[4]))
        let green = try #require(color(bars[3]))
        #expect(blue.b > blue.g)
        #expect(green.g > green.b)
        #expect(green.g > green.r)
    }

    @Test("barra activa con reps en objetivo (precarga [12,11,10]) → AZUL")
    func currentBlue() async throws {
        let bar = try #require(try await stripOfFirstCard(data()).1.bars.last)
        let c = try #require(color(bar))
        #expect(c.b > c.g)
    }

    @Test("bajar una rep por debajo del objetivo recolorea la barra activa a VERDE en vivo")
    func currentGreen() async throws {
        let (today, _) = try await stripOfFirstCard(data())
        today.model.focusSeries(2, at: 0)
        await today.model.chooseRep(8, series: 2, at: 0)
        let bar = try #require(today.model.activeCards[0].strip?.bars.last)
        let c = try #require(color(bar))
        #expect(c.g > c.b)
        #expect(c.g > c.r)
    }
}

@MainActor
@Suite("Colores de reps reales (celdas)")
struct SeriesCellColorTests {
    @Test("reps en objetivo → AZUL (.done); reps por debajo → VERDE (.filled)")
    func states() async {
        let data = TrainingData(
            catalog: Catalog([Exercise(id: "press_banca", name: "Press Banca")]),
            routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca"])],
            history: [Session(date: LocalDate(iso: "2024-01-08")!, routineID: "DIA1", completed: true,
                              logs: [ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 10, 8], weight: 60)])]
        )
        let history = await HistoryHarness.make(data)
        history.openFirstAndExpand()
        // El color de cada estado (azul el cumplido, verde el que se queda corto) lo pone la vista.
        #expect(history.model.cards[0].cells.map(\.state) == [.done, .done, .filled])
    }
}

import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

/// Los datos de los e2e de Estadísticas: un estancado (Press de Hombros), uno que progresa (Jalón)
/// y uno sin recorrido (Ejercicio Nuevo), con fechas relativas a hoy.
private func statsData() -> TrainingData {
    let today = SyncFixtures.today
    func log(_ id: ExerciseID, _ weight: Double, _ series: Int, _ expected: Int, _ actual: [Int?]) -> ExerciseLog {
        ExerciseLog(exerciseID: id, series: series, targetReps: expected, actualReps: actual, weight: weight)
    }
    func session(_ daysAgo: Int, _ logs: [ExerciseLog]) -> Session {
        Session(date: today.adding(days: -daysAgo), routineID: "DIA1", completed: true, logs: logs)
    }
    return TrainingData(
        catalog: Catalog([
            Exercise(id: "press_hombros", name: "Press de Hombros", group: .hombros),
            Exercise(id: "jalon", name: "Jalon al Pecho", group: .espalda),
            Exercise(id: "nuevo", name: "Ejercicio Nuevo", group: .espalda),
        ]),
        routines: [
            Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_hombros", "jalon", "nuevo"]),
            Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["press_hombros"]),
            Routine(id: "DIA3", name: "Full Body - Día 3", exerciseIDs: ["jalon"]),
        ],
        history: [
            session(28, [log("press_hombros", 18, 3, 11, [11, 11, 10]), log("jalon", 68, 4, 10, [10, 10, 9, 9])]),
            session(21, [log("press_hombros", 18, 3, 11, [11, 11, 10]), log("jalon", 68, 4, 10, [10, 10, 10, 9])]),
            session(14, [log("press_hombros", 18, 3, 11, [11, 10, 10]), log("jalon", 68, 4, 10, [10, 10, 10, 10])]),
            session(7, [log("press_hombros", 18, 3, 11, [11, 11, 10]), log("jalon", 68, 4, 11, [11, 11, 10, 10]), log("nuevo", 0, 3, 9, [9, 9, 8])]),
            session(1, [log("nuevo", 0, 3, 9, [9, 9, 9])]),
        ]
    )
}

/// Progreso con los datos de los e2e de Estadísticas (o los que se pasen), sin GitHub.
@MainActor
private struct ProgressHarness {
    let app: AppModel
    let model: ProgressModel

    static func make(_ data: TrainingData = statsData()) async -> ProgressHarness {
        let base = await AppHarness.start(local: data)
        return ProgressHarness(app: base.app, model: ProgressModel(app: base.app, clock: base.clock))
    }
}

// tests/e2e/estadisticas.spec.js
@MainActor
@Suite("Estadísticas")
struct StatsTests {
    @Test("la pestaña Progreso muestra las dos tarjetas")
    func twoCards() async {
        let model = await ProgressHarness.make().model
        #expect(!model.allRows.isEmpty)
        #expect(!model.groups.isEmpty)
        #expect([ProgressText.exercisesTitle, ProgressText.groupsTitle] == ["Ejercicios", "Grupos musculares"])
    }

    @Test("la tarjeta arranca plegada y solo muestra los estancados")
    func collapsed() async {
        let model = await ProgressHarness.make().model
        #expect(!model.isExpanded)
        #expect(model.exercisesSubtitle == "1 de 3 estancados")
        #expect(model.visibleRows.map(\.name) == ["Press de Hombros"])
    }

    @Test("tocar la cabecera de la tarjeta despliega y pliega el resto")
    func expand() async {
        let model = await ProgressHarness.make().model
        model.toggleExpanded()
        #expect(model.isExpanded)
        #expect(model.visibleRows.count == 3)
        model.toggleExpanded()
        #expect(model.visibleRows.count == 1)
    }

    @Test("cada fila trae nombre y frase; las reps van colapsadas")
    func rowContent() async {
        let row = await ProgressHarness.make().model.allRows[0]
        #expect(!row.name.isEmpty)
        #expect(!row.phrase.isEmpty)
        #expect(!row.isOpen)
    }

    @Test("tocar la cabecera despliega y pliega las reps")
    func toggleRow() async {
        let model = await ProgressHarness.make().model
        let id = model.allRows[0].exerciseID
        model.toggleRow(id)
        #expect(model.allRows[0].isOpen)
        #expect(!model.allRows[0].recentReps.isEmpty)
        model.toggleRow(id)
        #expect(!model.allRows[0].isOpen)
    }

    @Test("cada fila lleva su clase de color según el estado")
    func statuses() async {
        let rows = await ProgressHarness.make().model.allRows
        #expect(rows.first?.status == .stalled)
        #expect(rows.last?.status == .noTrack)
        #expect(rows.contains { $0.status == .progressing })
    }

    @Test("el estancado va primero y el ejercicio sin recorrido al final")
    func order() async {
        let rows = await ProgressHarness.make().model.allRows
        #expect(rows.count == 3)
        #expect(rows.first?.name == "Press de Hombros")
        #expect(rows.last?.name == "Ejercicio Nuevo")
        #expect(rows.last?.phrase == "2 sesiones, aún sin recorrido")
    }

    @Test("un ejercicio sin peso no muestra columna de kg")
    func noWeight() async {
        let rows = await ProgressHarness.make().model.allRows
        #expect(rows.last?.weight == nil)
        #expect(rows.first?.weight == "18 kg")
    }

    @Test("el ejercicio sin recorrido no ofrece botón de Gráficas")
    func noChartsButton() async {
        let rows = await ProgressHarness.make().model.allRows
        #expect(rows.last?.canOpenCharts == false)
        #expect(rows.first?.canOpenCharts == true)
    }

    // En la PWA el botón saltaba a la pestaña Gráficas y ponía un «Volver» propio. En la app las
    // gráficas del ejercicio entran empujadas dentro de Progreso y se vuelve con la flecha de iOS o
    // deslizando (decisión del usuario, 2026-10-25): los tres tests comprueban eso. Que no cambia de
    // pestaña lo garantiza la forma: ProgressModel no conoce la navegación. Por eso se quitó la
    // comprobación de la pestaña, que no podía fallar (aprobado por el usuario, 2026-10-29).
    @Test("el botón de dentro abre Gráficas con el ejercicio ya seleccionado")
    func openCharts() async throws {
        let model = await ProgressHarness.make().model
        let row = model.allRows[0]
        model.toggleRow(row.exerciseID)
        model.openCharts(row.exerciseID)
        let charts = try #require(model.charts)
        // La PWA lo comprobaba en el campo de búsqueda; en la app el elegido se ve en su fila
        // (`selectedName`) y el buscador solo filtra (aprobado por el usuario, 2026-10-25).
        #expect(charts.selected == row.exerciseID)
        #expect(charts.selectedName == row.name)
    }

    @Test("volver devuelve a Estadísticas")
    func back() async {
        let model = await ProgressHarness.make().model
        model.openCharts(model.allRows[0].exerciseID)
        model.closeCharts()
        #expect(model.charts == nil)
    }

    @Test("entrar a Gráficas desde la pestaña no muestra el botón de volver")
    func chartsFromTab() async {
        let progress = await ProgressHarness.make()
        let model = progress.model
        let tab = ChartsModel(app: progress.app, clock: FixedClock(SyncFixtures.today))
        model.openCharts(model.allRows[0].exerciseID)
        // La pestaña Gráficas es otra pantalla: no hereda el ejercicio que se abrió desde Progreso.
        #expect(tab.selected == nil)
    }

    @Test("tocar otra vez la pestaña cierra las gráficas empujadas")
    func reselectCloses() async {
        let model = await ProgressHarness.make().model
        model.openCharts(model.allRows[0].exerciseID)
        model.reselect()
        #expect(model.charts == nil)
    }

    @Test("cada grupo pinta la franja de referencia con sus dos límites")
    func band() async {
        let model = await ProgressHarness.make().model
        #expect(model.referenceBand == 32...80)
        #expect(model.scale >= Double(model.referenceBand.upperBound))
        #expect(ProgressText.referenceBand(model.referenceBand) == "32–80 series")
    }

    @Test("tocar un grupo despliega y pliega sus ejercicios")
    func toggleGroup() async {
        let model = await ProgressHarness.make().model
        let group = model.groups[0]
        #expect(!group.isOpen)
        model.toggleGroup(group.name)
        #expect(model.groups[0].isOpen)
        #expect(!model.groups[0].exercises.isEmpty)
        model.toggleGroup(group.name)
        #expect(!model.groups[0].isOpen)
    }
}

@MainActor
@Suite("Progreso")
struct ProgressModelTests {
    @Test("sin nada estancado, el subtítulo lo dice con palabras")
    func nothingStalled() {
        #expect(ProgressText.exercisesSubtitle(stalled: 0, total: 3, progressing: 2) == "Nada estancado · 2 progresando")
    }

    @Test("la escala es la decena por encima del grupo mayor o de la franja, y nunca menos de 10")
    func scale() async {
        let model = await ProgressHarness.make().model
        #expect(model.scale == 80)
        let empty = await ProgressHarness.make(TrainingData()).model
        #expect(empty.scale == 80)
    }

    @Test("los grupos dicen sus series y las de cada ejercicio con sus sesiones")
    func groupDetail() async throws {
        let model = await ProgressHarness.make().model
        let back = try #require(model.groups.first { $0.name == "Espalda" })
        #expect(back.sets == 22)
        #expect(back.exercises.first?.name == "Jalon al Pecho")
        #expect(back.exercises.first?.value == "16 · 4")
    }

    @Test("las series indirectas van con un decimal como mucho")
    func indirect() {
        #expect(ProgressText.indirectSets(2.5) == "2,5")
        #expect(ProgressText.indirectSets(3) == "3")
        #expect(ProgressText.indirectSets(1.25) == "1,3")
    }
}

// Propio de la app (repaso de la HIG, 2026-10-28): sin nada que comparar, Progreso dice cuál es el
// siguiente paso en vez de «Nada estancado · 0 progresando» y barras a cero.
@MainActor
@Suite("Progreso sin datos")
struct ProgressEmptyTests {
    @Test("sin entrenos no hay progreso que enseñar")
    func empty() async {
        let routines = [Routine(id: "DIA1", name: "Día 1", exerciseIDs: [])]
        #expect(await !ProgressHarness.make(TrainingData(routines: routines)).model.hasProgress)
    }

    @Test("con ejercicios sin recorrido tampoco")
    func onlyNoTrack() async {
        var data = statsData()
        data.history = [Session(date: SyncFixtures.today.adding(days: -1), routineID: "DIA1", completed: true,
                                logs: [ExerciseLog(exerciseID: "nuevo", series: 3, targetReps: 9, actualReps: [9, 9, 9], weight: 0)])]
        #expect(await !ProgressHarness.make(data).model.hasProgress)
    }

    @Test("con algo que progresa o se estanca, sí")
    func withData() async {
        #expect(await ProgressHarness.make().model.hasProgress)
    }
}

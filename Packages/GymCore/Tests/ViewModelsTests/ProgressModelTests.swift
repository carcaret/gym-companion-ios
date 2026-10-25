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

@MainActor
private func progress(_ data: TrainingData = statsData()) async -> (ProgressModel, NavigationModel, AppModel) {
    let app = AppModel(repository: SyncHarness(local: data, configured: false).repository())
    await app.start()
    let navigation = NavigationModel()
    navigation.select(.progress)
    return (ProgressModel(app: app, navigation: navigation, clock: FixedClock(SyncFixtures.today)), navigation, app)
}

// tests/e2e/estadisticas.spec.js
@MainActor
@Suite("Estadísticas")
struct StatsTests {
    @Test("la pestaña Progreso muestra las dos tarjetas")
    func twoCards() async {
        let model = await progress().0
        #expect(!model.allRows.isEmpty)
        #expect(!model.groups.isEmpty)
        #expect([StatsText.exercisesTitle, StatsText.groupsTitle] == ["Ejercicios", "Grupos musculares"])
    }

    @Test("la tarjeta arranca plegada y solo muestra los estancados")
    func collapsed() async {
        let model = await progress().0
        #expect(!model.isExpanded)
        #expect(model.exercisesSubtitle == "1 de 3 estancados")
        #expect(model.visibleRows.map(\.name) == ["Press de Hombros"])
    }

    @Test("tocar la cabecera de la tarjeta despliega y pliega el resto")
    func expand() async {
        let model = await progress().0
        model.toggleExpanded()
        #expect(model.isExpanded)
        #expect(model.visibleRows.count == 3)
        model.toggleExpanded()
        #expect(model.visibleRows.count == 1)
    }

    @Test("cada fila trae nombre y frase; las reps van colapsadas")
    func rowContent() async {
        let row = await progress().0.allRows[0]
        #expect(!row.name.isEmpty)
        #expect(!row.phrase.isEmpty)
        #expect(!row.isOpen)
    }

    @Test("tocar la cabecera despliega y pliega las reps")
    func toggleRow() async {
        let model = await progress().0
        let id = model.allRows[0].exerciseID
        model.toggleRow(id)
        #expect(model.allRows[0].isOpen)
        #expect(!model.allRows[0].recentReps.isEmpty)
        model.toggleRow(id)
        #expect(!model.allRows[0].isOpen)
    }

    @Test("cada fila lleva su clase de color según el estado")
    func statuses() async {
        let rows = await progress().0.allRows
        #expect(rows.first?.status == .stalled)
        #expect(rows.last?.status == .noTrack)
        #expect(rows.contains { $0.status == .progressing })
    }

    @Test("el estancado va primero y el ejercicio sin recorrido al final")
    func order() async {
        let rows = await progress().0.allRows
        #expect(rows.count == 3)
        #expect(rows.first?.name == "Press de Hombros")
        #expect(rows.last?.name == "Ejercicio Nuevo")
        #expect(rows.last?.phrase == "2 sesiones, aún sin recorrido")
    }

    @Test("un ejercicio sin peso no muestra columna de kg")
    func noWeight() async {
        let rows = await progress().0.allRows
        #expect(rows.last?.weight == nil)
        #expect(rows.first?.weight == "18 kg")
    }

    @Test("el ejercicio sin recorrido no ofrece botón de Gráficas")
    func noChartsButton() async {
        let rows = await progress().0.allRows
        #expect(rows.last?.canOpenCharts == false)
        #expect(rows.first?.canOpenCharts == true)
    }

    @Test("el botón de dentro abre Gráficas con el ejercicio ya seleccionado")
    func openCharts() async {
        let (model, navigation, app) = await progress()
        let row = model.allRows[0]
        model.toggleRow(row.exerciseID)
        model.openCharts(row.exerciseID)
        #expect(navigation.selectedTab == .charts)
        let charts = ChartsModel(app: app, navigation: navigation, clock: FixedClock(SyncFixtures.today))
        charts.appear()
        // La PWA lo comprobaba en el campo de búsqueda; en la app el elegido se ve en su fila
        // (`selectedName`) y el buscador solo filtra (aprobado por el usuario, 2026-10-25).
        #expect(charts.selected == row.exerciseID)
        #expect(charts.selectedName == row.name)
        #expect(charts.canGoBack)
    }

    @Test("volver devuelve a Estadísticas")
    func back() async {
        let (model, navigation, _) = await progress()
        model.openCharts(model.allRows[0].exerciseID)
        navigation.goBack()
        #expect(navigation.selectedTab == .progress)
    }

    @Test("entrar a Gráficas desde la pestaña no muestra el botón de volver")
    func chartsFromTab() async {
        let (_, navigation, app) = await progress()
        navigation.select(.charts)
        let charts = ChartsModel(app: app, navigation: navigation, clock: FixedClock(SyncFixtures.today))
        charts.appear()
        #expect(!charts.canGoBack)
    }

    @Test("cada grupo pinta la franja de referencia con sus dos límites")
    func band() async {
        let model = await progress().0
        #expect(model.referenceBand == 32...80)
        #expect(model.scale >= Double(model.referenceBand.upperBound))
        #expect(StatsText.referenceBand(model.referenceBand) == "32–80 series")
    }

    @Test("tocar un grupo despliega y pliega sus ejercicios")
    func toggleGroup() async {
        let model = await progress().0
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
        #expect(StatsText.exercisesSubtitle(stalled: 0, total: 3, progressing: 2) == "Nada estancado · 2 progresando")
    }

    @Test("la escala es la decena por encima del grupo mayor o de la franja, y nunca menos de 10")
    func scale() async {
        let model = await progress().0
        #expect(model.scale == 80)
        let empty = await progress(TrainingData()).0
        #expect(empty.scale == 80)
    }

    @Test("los grupos dicen sus series y las de cada ejercicio con sus sesiones")
    func groupDetail() async throws {
        let model = await progress().0
        let back = try #require(model.groups.first { $0.name == "Espalda" })
        #expect(back.sets == 22)
        #expect(back.exercises.first?.name == "Jalon al Pecho")
        #expect(back.exercises.first?.value == "16 · 4")
    }

    @Test("las series indirectas van con un decimal como mucho")
    func indirect() {
        #expect(StatsText.indirectSets(2.5) == "2,5")
        #expect(StatsText.indirectSets(3) == "3")
        #expect(StatsText.indirectSets(1.25) == "1,3")
    }
}

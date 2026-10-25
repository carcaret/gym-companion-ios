import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

@MainActor
private func charts(_ data: TrainingData = PWATestDB.data) async -> (ChartsModel, NavigationModel) {
    let app = AppModel(repository: SyncHarness(local: data, configured: false).repository())
    await app.start()
    let navigation = NavigationModel()
    return (ChartsModel(app: app, navigation: navigation, clock: FixedClock(SyncFixtures.today)), navigation)
}

private func day(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }

// tests/e2e/charts-full.spec.js
@MainActor
@Suite("Graficas completo")
struct ChartsFullTests {
    private func in2024() async -> ChartsModel {
        let model = await charts().0
        model.setRange(from: day("2024-01-01"), to: day("2024-12-31"))
        return model
    }

    private func all(_ model: ChartsModel) -> [ChartsModel.Option] {
        model.options.inRoutine + model.options.others
    }

    @Test("seleccionar ejercicio muestra 2 canvas")
    func twoCharts() async throws {
        let model = await in2024()
        let first = try #require(all(model).first)
        model.select(first.exerciseID)
        #expect(model.charts.count == 2)
        #expect(model.charts.allSatisfy { !$0.points.isEmpty })
    }

    @Test("cambiar rango de fechas actualiza lista de ejercicios")
    func rangeChangesList() async {
        let model = await in2024()
        let before = all(model).count
        model.setRange(from: day("2025-06-01"), to: day("2025-06-30"))
        #expect(all(model).count < before)
    }

    @Test("rango sin datos muestra dropdown vacio")
    func emptyRange() async {
        let model = await charts().0
        model.setRange(from: day("2030-01-01"), to: day("2030-12-31"))
        #expect(model.hasNoResults)
        #expect(ChartsText.noResults == "Sin resultados")
    }

    @Test("cambiar ejercicio actualiza graficas")
    func changeExercise() async throws {
        let model = await in2024()
        let options = all(model)
        model.select(options[0].exerciseID)
        let first = model.charts
        model.query = ""
        let refreshed = all(model)
        if refreshed.count > 1 {
            model.select(refreshed[1].exerciseID)
            #expect(!model.charts.isEmpty)
            #expect(model.charts != first)
        }
    }

    @Test("buscador filtra ejercicios en el dropdown")
    func search() async {
        let model = await in2024()
        let total = all(model).count
        model.query = "curl"
        #expect(all(model).count <= total)
        #expect(all(model).allSatisfy { $0.name.searchFolded.contains("curl") })
    }

    @Test("botón clear está oculto sin texto y visible con texto")
    func clearVisibility() async {
        let model = await charts().0
        #expect(!model.showsClear)
        model.query = "curl"
        #expect(model.showsClear)
    }

    @Test("botón clear limpia selección y abre dropdown")
    func clear() async throws {
        let model = await in2024()
        model.select(try #require(all(model).first).exerciseID)
        #expect(!model.query.isEmpty)
        #expect(model.showsClear)
        model.clear()
        #expect(model.query.isEmpty)
        #expect(!model.showsClear)
        #expect(model.selected == nil)
        #expect(!all(model).isEmpty)
        #expect(model.charts.isEmpty)
    }

    @Test("leyenda de gráficas no contiene nombre de ejercicio")
    func legend() async throws {
        let model = await in2024()
        let first = try #require(all(model).first)
        model.select(first.exerciseID)
        #expect(model.charts.allSatisfy { !$0.label.contains(first.name) })
        #expect(model.charts.contains { $0.label == "e1RM" })
    }
}

@MainActor
@Suite("Gráficas")
struct ChartsModelTests {
    @Test("por defecto, los últimos seis meses hasta hoy")
    func defaultRange() async {
        let model = await charts().0
        #expect(model.to == SyncFixtures.today)
        #expect(model.from == day("2026-04-25"))
    }

    @Test("seis meses antes de un 31 que no existe pasa al mes siguiente, como en JavaScript")
    func monthOverflow() async {
        let app = AppModel(repository: SyncHarness(local: PWATestDB.data, configured: false).repository())
        let model31 = ChartsModel(app: app, navigation: NavigationModel(), clock: FixedClock(day("2026-08-31")))
        #expect(model31.from == day("2026-03-03"))
    }

    @Test("sin ejercicio elegido no hay gráficas")
    func nothingSelected() async {
        #expect(await charts().0.charts.isEmpty)
    }

    @Test("los ejercicios de alguna rutina van primero, cada grupo por nombre")
    func groups() async {
        var data = PWATestDB.data
        data.catalog = Catalog(data.catalog.all + [Exercise(id: "remo", name: "Remo")])
        data.history.append(Session(date: day("2024-02-01"), routineID: "DIA1", completed: true,
                                    logs: [ExerciseLog(exerciseID: "remo", series: 3, targetReps: 10, actualReps: [10, 10, 10], weight: 40)]))
        let model = await charts(data).0
        model.setRange(from: day("2024-01-01"), to: day("2024-12-31"))
        #expect(model.options.inRoutine.map(\.name) == ["Curl Bíceps", "Press Banca", "Sentadilla"])
        #expect(model.options.others.map(\.name) == ["Remo"])
    }

    @Test("Progreso → Gráficas: el ejercicio llega elegido y hay botón de volver")
    func fromProgress() async {
        let (model, navigation) = await charts()
        model.setRange(from: day("2024-01-01"), to: day("2024-12-31"))
        navigation.openCharts(for: "sentadilla", from: .progress)
        model.appear()
        #expect(model.selected == "sentadilla")
        #expect(model.query == "Sentadilla")
        #expect(model.canGoBack)
        model.goBack()
        #expect(navigation.selectedTab == .progress)
    }

    @Test("cambiar el rango fuera del ejercicio elegido lo olvida")
    func rangeForgets() async {
        let model = await charts().0
        model.setRange(from: day("2024-01-01"), to: day("2024-12-31"))
        model.select("sentadilla")
        model.setRange(from: day("2025-01-01"), to: day("2025-12-31"))
        #expect(model.selected == nil)
        #expect(model.query.isEmpty)
    }

    @Test("el detalle de un punto dice la serie y el valor, y si se saltó")
    func pointLabel() {
        #expect(ChartsText.pointLabel("e1RM", value: 84, carriedForward: false) == "e1RM: 84")
        #expect(ChartsText.pointLabel("Peso", value: 52.5, carriedForward: true) == "Peso: 52.5 · saltado (mantiene)")
    }
}

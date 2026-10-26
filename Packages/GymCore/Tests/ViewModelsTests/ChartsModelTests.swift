import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

@MainActor
private func charts(_ data: TrainingData = PWATestDB.data) async -> (ChartsModel, AppModel) {
    let app = AppModel(repository: SyncHarness(local: data, configured: false).repository())
    await app.start()
    return (ChartsModel(app: app, clock: FixedClock(SyncFixtures.today)), app)
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

    // En la PWA el campo hacía de desplegable y se comprobaba su "x". En la app el buscador
    // está en la pantalla de elegir (`.searchable`, que pone su propia "x") y solo filtra:
    // empieza vacío y elegir lo vacía (cambiado con aprobación del usuario, 2026-10-25).
    @Test("botón clear está oculto sin texto y visible con texto")
    func clearVisibility() async throws {
        let model = await in2024()
        #expect(model.query.isEmpty)
        model.query = "curl"
        model.select(try #require(all(model).first).exerciseID)
        #expect(model.query.isEmpty)
        #expect(model.selectedName?.searchFolded.contains("curl") == true)
    }

    // En la PWA, tras elegir, el nombre quedaba en el campo. En la app se ve en la fila del
    // ejercicio elegido (`selectedName`) (cambiado con aprobación del usuario, 2026-10-25).
    @Test("botón clear limpia selección y abre dropdown")
    func clear() async throws {
        let model = await in2024()
        #expect(model.selectedName == nil)
        let first = try #require(all(model).first)
        model.select(first.exerciseID)
        #expect(model.selectedName == first.name)
        model.clear()
        #expect(model.query.isEmpty)
        #expect(model.selected == nil)
        #expect(model.selectedName == nil)
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
        #expect(model.preset == .sixMonths)
    }

    @Test("un atajo pone el rango desde esos meses antes hasta hoy")
    func presets() async {
        let model = await charts().0
        model.setRange(from: day("2024-01-01"), to: day("2024-12-31"))
        model.choose(preset: .oneMonth)
        #expect(model.from == day("2026-09-25"))
        #expect(model.to == SyncFixtures.today)
        #expect(model.preset == .oneMonth)
        model.choose(preset: .threeMonths)
        #expect(model.from == day("2026-07-25"))
        model.choose(preset: .oneYear)
        #expect(model.from == day("2025-10-25"))
    }

    @Test("«Todo» empieza en la primera sesión")
    func allPreset() async throws {
        let model = await charts().0
        model.choose(preset: .all)
        let first = try #require(PWATestDB.data.history.sortedChronologically().first?.date)
        #expect(model.from == first)
        #expect(model.to == SyncFixtures.today)
        #expect(model.preset == .all)
    }

    @Test("«Todo» sin sesiones es solo hoy")
    func allPresetEmpty() async {
        let model = await charts(TrainingData()).0
        model.choose(preset: .all)
        #expect(model.from == SyncFixtures.today)
    }

    @Test("cambiar las fechas a mano deja el rango sin atajo")
    func customRange() async {
        let model = await charts().0
        model.setRange(from: day("2024-01-01"), to: day("2024-12-31"))
        #expect(model.preset == nil)
    }

    @Test("un atajo olvida el ejercicio elegido si no se hizo en su rango")
    func presetForgets() async {
        let model = await charts().0
        model.setRange(from: day("2024-01-01"), to: day("2024-12-31"))
        model.select("sentadilla")
        model.choose(preset: .oneMonth)
        #expect(model.selected == nil)
    }

    @Test("los atajos, cortos en el botón y enteros para VoiceOver")
    func presetTexts() {
        #expect(ChartsModel.RangePreset.allCases.map { ChartsText.presetLabel(months: $0.months) } == ["1M", "3M", "6M", "1A", "Todo"])
        #expect(ChartsModel.RangePreset.allCases.map { ChartsText.presetAccessibilityLabel(months: $0.months) }
            == ["1 mes", "3 meses", "6 meses", "1 año", "Todo"])
    }

    @Test("seis meses antes de un 31 que no existe pasa al mes siguiente, como en JavaScript")
    func monthOverflow() async {
        let app = AppModel(repository: SyncHarness(local: PWATestDB.data, configured: false).repository())
        let model31 = ChartsModel(app: app, clock: FixedClock(day("2026-08-31")))
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

@Suite("Eje de las gráficas")
struct ChartValueRangeTests {
    private func chart(_ values: [Double]) -> ChartsModel.Chart {
        let points = values.enumerated().map { ChartPoint(date: LocalDate(iso: "2026-10-0\($0.offset + 1)")!, value: $0.element) }
        return ChartsModel.Chart(label: "e1RM", axisTitle: "e1RM (kg)", points: points)
    }

    @Test("se ajusta a los valores con un 10 % de margen, sin empezar en 0")
    func fitsTheValues() {
        #expect(chart([70, 85, 90]).valueRange == 68...92)
    }

    @Test("nunca baja de 0")
    func neverBelowZero() {
        #expect(chart([0, 50]).valueRange.lowerBound == 0)
    }

    @Test("con un solo valor deja margen a los dos lados")
    func singleValue() {
        #expect(chart([60]).valueRange == 54...66)
        #expect(chart([0.5]).valueRange == 0...1.5)
    }

    @Test("sin puntos, un eje cualquiera")
    func empty() {
        #expect(chart([]).valueRange == 0...1)
    }
}

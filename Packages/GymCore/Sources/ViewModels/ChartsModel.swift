import Application
import Domain
import Observation
import Presentation

/// La pestaña Gráficas (`views/charts.js` de la PWA): un rango de fechas (con atajos de meses, como
/// la app Salud, o a mano), el ejercicio elegido (en su propia pantalla, con buscador y los de alguna
/// rutina primero) y sus gráficas de 1RM estimado y de peso. Sin ejercicio elegido no se pinta nada.
@MainActor
@Observable
public final class ChartsModel {
    public struct Option: Hashable, Sendable, Identifiable {
        public var id: ExerciseID { exerciseID }
        public let exerciseID: ExerciseID
        public let name: String
        public let isSelected: Bool
    }

    /// Una gráfica: su título del eje y la serie (ya sin el nombre del ejercicio en la leyenda).
    public struct Chart: Hashable, Sendable {
        public let label: String
        public let axisTitle: String
        public let points: [ChartPoint]

        public init(label: String, axisTitle: String, points: [ChartPoint]) {
            self.label = label
            self.axisTitle = axisTitle
            self.points = points
        }

        /// El eje vertical, ajustado a los valores como en Chart.js (que no empieza en 0) con un
        /// margen de un 10 % arriba y abajo, sin bajar de 0. Swift Charts, con el relleno bajo la
        /// línea, incluiría el 0 y aplastaría la línea arriba.
        public var valueRange: ClosedRange<Double> {
            let values = points.map(\.value)
            guard let low = values.min(), let high = values.max() else { return 0...1 }
            let margin = high > low ? (high - low) / 10 : max(abs(high) / 10, 1)
            return max(0, low - margin)...(high + margin)
        }
    }

    /// Los atajos del rango: hasta hoy, desde esos meses antes o desde la primera sesión.
    public enum RangePreset: CaseIterable, Hashable, Sendable {
        case oneMonth, threeMonths, sixMonths, oneYear, all

        /// `nil`: desde la primera sesión.
        public var months: Int? {
            switch self {
            case .oneMonth: 1
            case .threeMonths: 3
            case .sixMonths: 6
            case .oneYear: 12
            case .all: nil
            }
        }
    }

    public private(set) var from: LocalDate
    public private(set) var to: LocalDate
    /// El atajo del rango, o `nil` si las fechas se han cambiado a mano.
    public private(set) var preset: RangePreset? = .sixMonths
    /// Lo buscado en la pantalla de elegir ejercicio. Solo filtra: la PWA dejaba en el campo el
    /// nombre del elegido porque hacía de desplegable; aquí el elegido se ve en `selectedName`.
    public var query = ""
    public private(set) var selected: ExerciseID?

    private let app: AppModel
    private let clock: any Clock

    public init(app: AppModel, clock: any Clock) {
        self.app = app
        self.clock = clock
        let today = clock.today()
        to = today
        from = today.adding(months: -6)
    }

    private var data: TrainingData { app.data ?? TrainingData() }

    /// Desde otra pantalla (Progreso): el ejercicio queda elegido si se hizo en el rango.
    public func choose(_ exercise: ExerciseID) {
        if data.exercisesTrained(from: from, to: to).contains(exercise) {
            select(exercise)
        }
    }

    /// Un atajo: hasta hoy.
    public func choose(preset: RangePreset) {
        let today = clock.today()
        let start = preset.months.map { today.adding(months: -$0) } ?? data.history.sortedChronologically().first?.date ?? today
        setRange(from: start, to: today)
        self.preset = preset
    }

    /// Cambiar el rango a mano lo deja sin atajo y olvida el ejercicio elegido si no se hizo en él.
    public func setRange(from newFrom: LocalDate, to newTo: LocalDate) {
        preset = nil
        from = newFrom
        to = newTo
        if let selected, !data.exercisesTrained(from: from, to: to).contains(selected) {
            clear()
        }
    }

    /// Los ejercicios hechos en el rango que casan con la búsqueda: los de alguna rutina y el resto.
    public var options: (inRoutine: [Option], others: [Option]) {
        let needle = query.trimmingWhitespace().searchFolded
        let trained = data.exercisesTrained(from: from, to: to).filter { needle.isEmpty || data.catalog.name(of: $0).searchFolded.contains(needle) }
        let split = data.catalog.splitByRoutine(trained, routineExerciseIDs: data.routines.flatMap(\.exerciseIDs))
        func option(_ id: ExerciseID) -> Option { Option(exerciseID: id, name: data.catalog.name(of: id), isSelected: id == selected) }
        return (split.inRoutine.map(option), split.others.map(option))
    }

    /// "Sin resultados" en vez de la lista.
    public var hasNoResults: Bool { options.inRoutine.isEmpty && options.others.isEmpty }

    /// El nombre del ejercicio elegido, para la fila que abre la pantalla de elegir.
    public var selectedName: String? { selected.map { data.catalog.name(of: $0) } }

    /// Elegir deja el buscador vacío para la próxima vez.
    public func select(_ exercise: ExerciseID) {
        selected = exercise
        query = ""
    }

    public func clear() {
        selected = nil
        query = ""
    }

    /// 1RM estimado y peso, o nada sin ejercicio elegido.
    public var charts: [Chart] {
        guard let selected else { return [] }
        let series = data.history.chartSeries(for: [selected], from: from, to: to)
        return [
            Chart(label: ChartsText.e1rmLabel, axisTitle: ChartsText.e1rmAxis, points: series.e1RM.first?.points ?? []),
            Chart(label: ChartsText.weightLabel, axisTitle: ChartsText.weightAxis, points: series.weight.first?.points ?? []),
        ]
    }
}

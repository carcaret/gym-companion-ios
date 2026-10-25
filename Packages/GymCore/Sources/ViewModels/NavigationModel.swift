import Domain
import Observation

/// Las pestañas de la app, en el orden de la barra.
public enum AppTab: Hashable, Sendable, CaseIterable {
    case routines, history, progress, charts, settings
}

/// La pestaña visible y los saltos entre pantallas (`navigateToTab` de la PWA). Lo que pasa dentro
/// de cada pestaña (detalle de una sesión, catálogo...) lo lleva su `NavigationStack`, que ya
/// recuerda la posición al volver.
@MainActor
@Observable
public final class NavigationModel {
    public var selectedTab: AppTab = .routines {
        didSet { if !isJumping { returnTab = nil } }
    }
    /// El ejercicio con el que se abrió Gráficas desde otra pantalla, hasta que Gráficas lo recoge.
    public private(set) var chartsExercise: ExerciseID?
    /// De dónde se saltó; tocar una pestaña a mano lo borra.
    private var returnTab: AppTab?
    private var isJumping = false

    public init() {}

    /// Tocar una pestaña.
    public func select(_ tab: AppTab) {
        selectedTab = tab
    }

    /// Progreso → Gráficas con un ejercicio, y con botón de volver.
    public func openCharts(for exercise: ExerciseID, from origin: AppTab) {
        chartsExercise = exercise
        jump(to: .charts)
        returnTab = origin
    }

    /// Recoge el ejercicio pedido (una sola vez).
    public func takeChartsExercise() -> ExerciseID? {
        defer { chartsExercise = nil }
        return chartsExercise
    }

    public var canGoBack: Bool { returnTab != nil }

    /// El botón de volver de Gráficas.
    public func goBack() {
        guard let target = returnTab else { return }
        jump(to: target)
        returnTab = nil
    }

    /// Historial → Rutinas.
    public func showRoutines() {
        selectedTab = .routines
    }

    private func jump(to tab: AppTab) {
        isJumping = true
        selectedTab = tab
        isJumping = false
    }
}

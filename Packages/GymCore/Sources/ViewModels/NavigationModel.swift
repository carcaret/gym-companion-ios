import Domain
import Observation

/// Las pestañas de la app, en el orden de la barra.
public enum AppTab: Hashable, Sendable, CaseIterable {
    case routines, history, progress, charts
}

/// La pestaña visible (`navigateToTab` de la PWA). Lo que pasa dentro de cada pestaña (detalle de
/// una sesión, catálogo, gráficas de un ejercicio...) lo lleva su `NavigationStack`, que conserva
/// la pantalla al cambiar de pestaña, como en iOS.
@MainActor
@Observable
public final class NavigationModel {
    /// Tocar otra vez la pestaña activa: su pantalla vuelve a la de entrada. `count` distingue un
    /// toque del siguiente.
    public struct Reselection: Equatable, Sendable {
        public let tab: AppTab
        public let count: Int
    }

    public private(set) var selectedTab: AppTab = .routines
    public private(set) var reselection: Reselection?

    public init() {}

    /// Tocar una pestaña.
    public func select(_ tab: AppTab) {
        if tab == selectedTab {
            reselection = Reselection(tab: tab, count: (reselection?.count ?? 0) + 1)
        } else {
            selectedTab = tab
        }
    }

    /// Historial → Rutinas.
    public func showRoutines() {
        selectedTab = .routines
    }
}

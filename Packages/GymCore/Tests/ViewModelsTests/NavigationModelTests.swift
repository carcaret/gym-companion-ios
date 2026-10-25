import Domain
import Testing
import ViewModels

// Navegación de la PWA (`navigateToTab`, `gym:navigate` y `gym:navigate-back` de app.js; botón de
// volver de `views/charts.js`).
@MainActor
@Suite("Navegación")
struct NavigationModelTests {
    @Test("arranca en Rutinas")
    func startsOnRoutines() {
        #expect(NavigationModel().selectedTab == .routines)
    }

    @Test("las pestañas son Rutinas, Historial, Progreso, Gráficas y Ajustes, en ese orden")
    func tabs() {
        #expect(AppTab.allCases == [.routines, .history, .progress, .charts, .settings])
    }

    @Test("tocar una pestaña la selecciona")
    func select() {
        let navigation = NavigationModel()
        navigation.select(.history)
        #expect(navigation.selectedTab == .history)
    }

    @Test("Progreso → Gráficas con el ejercicio elegido y con botón de volver")
    func chartsFromProgress() {
        let navigation = NavigationModel()
        navigation.select(.progress)
        navigation.openCharts(for: "press_banca", from: .progress)
        #expect(navigation.selectedTab == .charts)
        #expect(navigation.chartsExercise == "press_banca")
        #expect(navigation.canGoBack)
        navigation.goBack()
        #expect(navigation.selectedTab == .progress)
        #expect(!navigation.canGoBack)
    }

    @Test("Gráficas desde su pestaña no tiene botón de volver")
    func chartsFromTab() {
        let navigation = NavigationModel()
        navigation.select(.charts)
        #expect(!navigation.canGoBack)
        navigation.goBack()
        #expect(navigation.selectedTab == .charts)
    }

    @Test("tocar una pestaña a mano borra el volver: solo vale dentro del salto que lo creó")
    func manualTabClearsBack() {
        let navigation = NavigationModel()
        navigation.openCharts(for: "press_banca", from: .progress)
        navigation.select(.history)
        navigation.select(.charts)
        #expect(!navigation.canGoBack)
    }

    @Test("Gráficas recuerda el ejercicio hasta que se elige otro")
    func chartsExerciseConsumed() {
        let navigation = NavigationModel()
        navigation.openCharts(for: "press_banca", from: .progress)
        #expect(navigation.takeChartsExercise() == "press_banca")
        #expect(navigation.takeChartsExercise() == nil)
    }

    @Test("Historial → Rutinas (al marcar como completada una sesión de hoy)")
    func historyToRoutines() {
        let navigation = NavigationModel()
        navigation.select(.history)
        navigation.showRoutines()
        #expect(navigation.selectedTab == .routines)
        #expect(!navigation.canGoBack)
    }
}

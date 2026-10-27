import Domain
import Testing
import ViewModels

// Navegación de la PWA (`navigateToTab` de app.js), con las pestañas de iOS.
@MainActor
@Suite("Navegación")
struct NavigationModelTests {
    @Test("arranca en Rutinas")
    func startsOnRoutines() {
        #expect(NavigationModel().selectedTab == .routines)
    }

    // Sin pestaña Ajustes: la configuración de GitHub se abre desde el indicador de la
    // sincronización (decisión del usuario, 2026-10-26).
    @Test("las pestañas son Rutinas, Historial, Progreso y Gráficas, en ese orden")
    func tabs() {
        #expect(AppTab.allCases == [.routines, .history, .progress, .charts])
    }

    @Test("tocar una pestaña la selecciona")
    func select() {
        let navigation = NavigationModel()
        navigation.select(.history)
        #expect(navigation.selectedTab == .history)
    }

    // Gráficas desde Progreso ya no salta de pestaña ni tiene botón de volver propio: entra
    // empujada dentro de Progreso (`ProgressModel.openCharts`), con la vuelta de iOS (decisión del
    // usuario, 2026-10-25).

    // Como en iOS: cambiar de pestaña conserva la pantalla de cada una; tocar otra vez la pestaña
    // activa vuelve a su pantalla de entrada. La PWA volvía a la entrada al cambiar de pestaña
    // (decisión del usuario, 2026-10-25).
    @Test("tocar otra vez la pestaña activa la vuelve a seleccionar, sin cambiar de pestaña")
    func reselect() {
        let navigation = NavigationModel()
        navigation.select(.history)
        #expect(navigation.reselection == nil)
        navigation.select(.history)
        #expect(navigation.selectedTab == .history)
        #expect(navigation.reselection?.tab == .history)
    }

    @Test("tocarla dos veces seguidas cuenta dos veces")
    func reselectTwice() {
        let navigation = NavigationModel()
        navigation.select(.routines)
        let first = navigation.reselection
        navigation.select(.routines)
        #expect(navigation.reselection != first)
        #expect(navigation.reselection?.tab == .routines)
    }

    @Test("cambiar a otra pestaña no cuenta como volver a tocarla")
    func switchIsNotReselect() {
        let navigation = NavigationModel()
        navigation.select(.history)
        navigation.select(.routines)
        #expect(navigation.reselection == nil)
    }
}

import SwiftUI
import ViewModels

/// La raíz: las cinco pestañas de la PWA, cada una con su pila de navegación y el indicador de
/// sincronización en la barra.
struct RootView: View {
    let root: CompositionRoot
    @Bindable var navigation: NavigationModel

    init(root: CompositionRoot) {
        self.root = root
        navigation = root.navigation
    }

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab("Rutinas", systemImage: "dumbbell", value: AppTab.routines) {
                stack { TodayScreen(model: root.today) }
            }
            Tab("Historial", systemImage: "clock", value: AppTab.history) {
                stack { HistoryScreen(model: root.history) }
            }
            Tab("Progreso", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                stack { ProgressScreen(model: root.progress, footer: AnyView(CatalogCard(model: root.catalog))) }
            }
            Tab("Gráficas", systemImage: "chart.bar", value: AppTab.charts) {
                stack { ChartsScreen(model: root.charts) }
            }
            Tab("Ajustes", systemImage: "gearshape", value: AppTab.settings) {
                stack { SettingsScreen(model: root.settings) }
            }
        }
        // Al volver a Rutinas o a Historial, su pantalla de entrada, como en la PWA. Al cambiar de
        // pestaña y no en el `onAppear` de la pantalla: ese salta también al empezar a deslizar
        // para volver, y cerraba el detalle de golpe en mitad del gesto.
        .onChange(of: navigation.selectedTab) { _, tab in
            switch tab {
            case .routines: root.today.appear()
            case .history: root.history.appear()
            case .progress, .charts, .settings: break
            }
        }
        .syncPresentation(root.sync)
        .tint(Theme.accentLight)
        .preferredColorScheme(.dark)
        // La app está solo en español: selectores de fecha y ejes de las gráficas también.
        .environment(\.locale, Locale(identifier: "es_ES"))
    }

    private func stack(@ViewBuilder _ content: () -> some View) -> some View {
        NavigationStack {
            content()
                .screenBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { SyncIndicator(sync: root.sync) }
                }
        }
    }
}

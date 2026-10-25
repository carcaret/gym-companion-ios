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
        .syncPresentation(root.sync)
    }

    private func stack(@ViewBuilder _ content: () -> some View) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { SyncIndicator(sync: root.sync) }
                }
        }
    }
}

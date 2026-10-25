import Domain
import SwiftUI
import ViewModels

/// La raíz: las cinco pestañas de la PWA, cada una con su pila de navegación y el indicador de
/// sincronización en la barra.
struct RootView: View {
    let version: AppVersion
    let app: AppModel
    let sync: SyncModel
    let today: TodayModel
    let history: HistoryModel
    @Bindable var navigation: NavigationModel

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab("Rutinas", systemImage: "dumbbell", value: AppTab.routines) {
                NavigationStack {
                    TodayScreen(model: today)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { SyncIndicator(sync: sync) }
                        }
                }
            }
            Tab("Historial", systemImage: "clock", value: AppTab.history) {
                NavigationStack {
                    HistoryScreen(model: history)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { SyncIndicator(sync: sync) }
                        }
                }
            }
            Tab("Progreso", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                screen("Progreso") { PendingScreen(issue: 12) }
            }
            Tab("Gráficas", systemImage: "chart.bar", value: AppTab.charts) {
                screen("Gráficas") { PendingScreen(issue: 11) }
            }
            Tab("Ajustes", systemImage: "gearshape", value: AppTab.settings) {
                screen("Ajustes") {
                    PendingScreen(issue: 14)
                        .safeAreaInset(edge: .bottom) {
                            Text("Versión \(version.label)").font(.footnote).foregroundStyle(.secondary).padding()
                        }
                }
            }
        }
        .syncPresentation(sync)
    }

    private func screen(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { SyncIndicator(sync: sync) }
                }
        }
    }
}

/// Lo que aún no está hecho, con la issue que lo hará.
struct PendingScreen: View {
    let issue: Int

    var body: some View {
        ContentUnavailableView("En camino", systemImage: "hammer", description: Text("Llega con la issue #\(issue)."))
    }
}

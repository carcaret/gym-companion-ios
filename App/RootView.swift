import Presentation
import SwiftUI
import ViewModels

/// La raíz: las pestañas de la PWA, cada una con su pila de navegación y el indicador de
/// sincronización en la barra. Ajustes no es una pestaña: es una hoja que abre el indicador
/// (decisión del usuario, 2026-10-26).
struct RootView: View {
    let root: CompositionRoot
    @Bindable var navigation: NavigationModel
    /// Lo empujado con `NavigationLink(value:)` en cada pestaña (catálogo, elegir ejercicio). El
    /// detalle del historial, la vista previa y las gráficas de Progreso los lleva su modelo.
    @State private var paths: [AppTab: NavigationPath] = [:]

    init(root: CompositionRoot) {
        self.root = root
        navigation = root.navigation
    }

    var body: some View {
        // Por `select`, que distingue tocar otra pestaña de volver a tocar la activa.
        TabView(selection: Binding(get: { navigation.selectedTab }, set: { navigation.select($0) })) {
            Tab("Rutinas", systemImage: "dumbbell", value: AppTab.routines) {
                stack(.routines) { TodayScreen(model: root.today) }
            }
            Tab("Historial", systemImage: "clock", value: AppTab.history) {
                stack(.history) { HistoryScreen(model: root.history, sync: root.sync) }
            }
            Tab("Progreso", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                stack(.progress) {
                    ProgressScreen(model: root.progress, footer: AnyView(CatalogCard(model: root.catalog)))
                        .navigationDestination(for: CatalogRoute.self) { _ in CatalogScreen(model: root.catalog).syncToolbar() }
                        // El catálogo, siempre a la vista en la barra; la tarjeta del final, además,
                        // dice cuántos hay y cuántos sin grupo (2026-10-27).
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                NavigationLink(value: CatalogRoute()) { Image(systemName: "list.bullet") }
                                    .accessibilityLabel(CatalogText.cardTitle)
                                    .accessibilityIdentifier("catalog-button")
                            }
                        }
                }
            }
            Tab("Gráficas", systemImage: "chart.bar", value: AppTab.charts) {
                stack(.charts) { ChartsScreen(model: root.charts) }
            }
        }
        // Como en iOS: cambiar de pestaña conserva su pantalla, y tocar otra vez la pestaña activa
        // vuelve a la de entrada (decisión del usuario, 2026-10-25). Nunca en el `onAppear` de la
        // pantalla: ese salta también al empezar a deslizar para volver, y cerraba el detalle de
        // golpe en mitad del gesto.
        .onChange(of: navigation.reselection) { _, reselection in
            guard let tab = reselection?.tab else { return }
            paths[tab] = NavigationPath()
            switch tab {
            case .routines: root.today.reselect()
            case .history: root.history.reselect()
            case .progress: root.progress.reselect()
            case .charts: break
            }
        }
        // Si los datos no se pueden leer, la app no sale vacía como si no hubiera nada: lo dice,
        // encima de todo, y ofrece reintentar o descargarlos de GitHub (2026-10-27).
        .overlay {
            if root.model.loadError != nil {
                DataLoadErrorView(model: root.model, sync: root.sync)
            }
        }
        .alert(DataErrorText.saveTitle, isPresented: Bindable(root.model).isSaveErrorPresented) {
            Button(DataErrorText.understood) {}
        } message: {
            Text(DataErrorText.saveMessage)
        }
        .syncPresentation(root.sync, noticeDuration: root.noticeDuration, isActive: !root.sync.isSettingsPresented)
        .sheet(isPresented: Bindable(root.sync).isSettingsPresented) {
            NavigationStack { SettingsScreen(model: root.settings) }
                .syncPresentation(root.sync, noticeDuration: root.noticeDuration)
        }
        // Para la nube de cada pantalla (`syncToolbar`).
        .environment(root.sync)
        .tint(Theme.accentLight)
        .preferredColorScheme(.dark)
        // La app está solo en español: selectores de fecha y ejes de las gráficas también.
        .environment(\.locale, Locale(identifier: "es_ES"))
        // Letra grande del iPhone (Dynamic Type) hasta el primer tamaño de accesibilidad: más allá
        // las filas de las tarjetas ya no caben en el ancho de un iPhone.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func stack(_ tab: AppTab, @ViewBuilder _ content: () -> some View) -> some View {
        NavigationStack(path: Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })) {
            content()
                .screenBackground()
                .syncToolbar()
        }
    }
}

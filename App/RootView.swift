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
                stack(.routines) { TodayScreen(model: root.today).overlay(alignment: .topLeading) { AnimationProbe(id: "s1", top: 140) } }
            }
            Tab("Historial", systemImage: "clock", value: AppTab.history) {
                stack(.history) { HistoryScreen(model: root.history, sync: root.sync) }
            }
            Tab("Progreso", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                stack(.progress) {
                    ProgressScreen(model: root.progress, footer: AnyView(CatalogCard(model: root.catalog)))
                        .navigationDestination(for: CatalogRoute.self) { _ in CatalogScreen(model: root.catalog) }
                }
            }
            Tab("Gráficas", systemImage: "chart.bar", value: AppTab.charts) {
                stack(.charts) { ChartsScreen(model: root.charts) }
            }
        }
        .overlay(alignment: .topLeading) { AnimationProbe(id: "s2", top: 180) }
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
        .syncPresentation(root.sync, noticeDuration: root.noticeDuration, isActive: !root.sync.isSettingsPresented)
        .overlay(alignment: .topLeading) { AnimationProbe(id: "s3", top: 220) }
        .sheet(isPresented: Bindable(root.sync).isSettingsPresented) {
            NavigationStack { SettingsScreen(model: root.settings) }
                .syncPresentation(root.sync, noticeDuration: root.noticeDuration, bottomInset: 16)
        }
        .tint(Theme.accentLight)
        .preferredColorScheme(.dark)
        // La app está solo en español: selectores de fecha y ejes de las gráficas también.
        .environment(\.locale, Locale(identifier: "es_ES"))
        .overlay(alignment: .topLeading) { AnimationProbe(id: "s4", top: 260) }
        .overlay(alignment: .topLeading) { ModelProbe(top: 380) }
        // Letra grande del iPhone (Dynamic Type) hasta el primer tamaño de accesibilidad: más allá
        // las filas de las tarjetas ya no caben en el ancho de un iPhone.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // Solo en la rama de prueba visual: si iOS pide reducir el movimiento.
        .overlay(alignment: .bottomLeading) { ReduceMotionProbe().padding(.bottom, 120).padding(.leading, 8) }
    }

    private func stack(_ tab: AppTab, @ViewBuilder _ content: () -> some View) -> some View {
        NavigationStack(path: Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })) {
            content()
                .screenBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        SyncIndicator(sync: root.sync)
                    }
                }
        }
    }
}

private struct ReduceMotionProbe: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wide = false

    var body: some View {
        VStack(alignment: .leading) {
            Button { withAnimation(.linear(duration: 2)) { wide.toggle() } } label: {
                Rectangle().fill(.yellow).frame(width: wide ? 300 : 30, height: 24)
            }
            .accessibilityIdentifier("sonda-animacion")
            label
        }
    }

    private var label: some View {
        Text("REDUCIR MOVIMIENTO: \(reduceMotion ? "SÍ" : "NO") · UIKit: \(UIAccessibility.isReduceMotionEnabled ? "SÍ" : "NO")")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.yellow)
            .background(.black)
    }
}

/// Solo en la rama de prueba visual: una barra que crece en 2 s al tocarla, con su propio estado.
struct AnimationProbe: View {
    let id: String
    let top: CGFloat
    @State private var wide = false

    var body: some View {
        Button { withAnimation(.linear(duration: 2)) { wide.toggle() } } label: {
            HStack(spacing: 4) {
                Text(id).font(.system(size: 12, weight: .bold)).foregroundStyle(.black)
                Rectangle().fill(.black).frame(width: wide ? 260 : 20, height: 14)
            }
            .padding(2)
            .background(.orange)
        }
        .accessibilityIdentifier("sonda-\(id)")
        .padding(.top, top)
        .padding(.leading, 8)
    }
}

@Observable
final class ProbeModel {
    var wide = false
}

/// Como `AnimationProbe`, pero el estado está en un modelo `@Observable`.
struct ModelProbe: View {
    let top: CGFloat
    @State private var model = ProbeModel()

    var body: some View {
        Button { withAnimation(.linear(duration: 2)) { model.wide.toggle() } } label: {
            HStack(spacing: 4) {
                Text("s6").font(.system(size: 12, weight: .bold)).foregroundStyle(.black)
                Rectangle().fill(.black).frame(width: model.wide ? 260 : 20, height: 14)
            }
            .padding(2)
            .background(.green)
        }
        .accessibilityIdentifier("sonda-s6")
        .padding(.top, top)
        .padding(.leading, 8)
    }
}

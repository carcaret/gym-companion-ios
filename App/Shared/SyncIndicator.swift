import Application
import Presentation
import SwiftUI
import ViewModels

/// El estado de la sincronización en la barra: un menú que lo dice y ofrece lo que toca
/// (sincronizar ahora, resolver el conflicto o configurar GitHub) y los ajustes.
struct SyncIndicator: View {
    let sync: SyncModel

    var body: some View {
        Menu {
            Section(sync.statusText) {
                switch sync.menuAction {
                case .syncNow:
                    Button(SyncText.syncNowLabel, systemImage: "arrow.triangle.2.circlepath") { Task { await sync.pullToRefresh() } }
                case .resolveConflict:
                    Button(SyncText.resolveConflictLabel, systemImage: "exclamationmark.triangle") { sync.resolveConflict() }
                case .configure:
                    Button(SyncText.configureLabel, systemImage: "gearshape") { sync.showSettings() }
                }
            }
            if sync.offersSettings {
                Button(SyncText.settingsLabel, systemImage: "gearshape") { sync.showSettings() }
            }
        } label: {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: sync.indicatorPulses)
        }
        .accessibilityIdentifier(AccessibilityID.syncIndicator)
        .accessibilityLabel(sync.statusText)
    }

    private var symbol: String {
        switch sync.status.state {
        case .ok: "checkmark.icloud"
        case .pending: sync.status.conflict ? "exclamationmark.icloud" : "icloud.and.arrow.up"
        case .disabled: "icloud.slash"
        }
    }

    /// Verde sincronizado, dorado pendiente, gris sin configurar (`.sync-indicator`).
    private var color: Color {
        switch sync.status.state {
        case .ok: Theme.green
        case .pending: Theme.gold
        case .disabled: Theme.textSecondary
        }
    }

}

extension View {
    /// La nube en la barra. La lleva toda pantalla de una pila: la de entrada de cada pestaña y
    /// cada empujada, que trae su propia barra (antes solo salía en la de entrada, 2026-10-27). Va
    /// donde se empuja la pantalla, no dentro de ella: Gráficas es la entrada de su pestaña y
    /// también se empuja desde Progreso. El modelo llega por el entorno (`RootView`).
    func syncToolbar() -> some View {
        modifier(SyncToolbar(action: EmptyView()))
    }

    /// Con una acción de la pantalla a la izquierda de la nube, en su propia cápsula (iOS 26 junta
    /// en una lo que va seguido en la barra, y la nube no tiene que ver con la acción). La nube
    /// sigue en la esquina, como en todas las pantallas (decisión del usuario, 2026-10-27). En el
    /// mismo bloque de la barra para que el orden sea fijo.
    func syncToolbar(@ViewBuilder action: () -> some View) -> some View {
        modifier(SyncToolbar(action: action(), hasAction: true))
    }
}

private struct SyncToolbar<Action: View>: ViewModifier {
    @Environment(SyncModel.self) private var sync
    let action: Action
    var hasAction = false

    func body(content: Content) -> some View {
        content.toolbar {
            if hasAction {
                ToolbarItem(placement: .topBarTrailing) { action }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                SyncIndicator(sync: sync)
            }
        }
    }
}
